module Idv
  class WelcomeController < ApplicationController
    include IdvStepConcern
    include StepIndicatorConcern
    include GettingStartedAbTestConcern

    before_action :confirm_not_rate_limited
    before_action :confirm_document_capture_not_complete
    before_action :maybe_redirect_for_getting_started_ab_test

    def show
      analytics.idv_doc_auth_welcome_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('welcome', :view, true)

      @sp_name = decorated_sp_session.sp_name || APP_NAME
      @title = t('doc_auth.headings.getting_started', sp_name: @sp_name)

      @ab_test_bucket = getting_started_ab_test_bucket

      render :show
    end

    def update
      if !FeatureManagement.idv_available?
        redirect_to idv_unavailable_url
        return
      end

      analytics.idv_doc_auth_welcome_submitted(**analytics_arguments)

      create_document_capture_session
      cancel_previous_in_person_enrollments

      idv_session.welcome_visited = true

      redirect_to idv_agreement_url
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :welcome,
        controller: controller_name,
        next_steps: [:agreement],
        preconditions: ->(idv_session:, user:) { true },
      )
    end

    private

    def analytics_arguments
      {
        step: 'welcome',
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(ab_test_analytics_buckets)
    end

    def create_document_capture_session
      document_capture_session = DocumentCaptureSession.create(
        user_id: current_user.id,
        issuer: sp_session[:issuer],
      )
      idv_session.document_capture_session_uuid = document_capture_session.uuid
    end

    def cancel_previous_in_person_enrollments
      return unless IdentityConfig.store.in_person_proofing_enabled
      UspsInPersonProofing::EnrollmentHelper.
        cancel_stale_establishing_enrollments_for_user(current_user)
    end
  end
end
