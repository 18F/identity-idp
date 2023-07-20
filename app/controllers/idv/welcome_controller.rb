module Idv
  class WelcomeController < ApplicationController
    include IdvStepConcern
    include StepIndicatorConcern
    include GettingStartedAbTestConcern

    before_action :confirm_welcome_needed
    before_action :maybe_redirect_for_getting_started_ab_test

    def show
      analytics.idv_doc_auth_welcome_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('welcome', :view, true)

      render :show
    end

    def update
      flow_session[:skip_upload_step] = true unless FeatureManagement.idv_allow_hybrid_flow?

      analytics.idv_doc_auth_welcome_submitted(**analytics_arguments)

      create_document_capture_session
      cancel_previous_in_person_enrollments

      idv_session.welcome_visited = true

      redirect_to idv_agreement_url
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
      flow_session[:document_capture_session_uuid] = document_capture_session.uuid
    end

    def cancel_previous_in_person_enrollments
      return unless IdentityConfig.store.in_person_proofing_enabled
      UspsInPersonProofing::EnrollmentHelper.
        cancel_stale_establishing_enrollments_for_user(current_user)
    end

    def confirm_welcome_needed
      return unless idv_session.welcome_visited

      redirect_to idv_agreement_url
    end
  end
end
