# frozen_string_literal: true

module Idv
  class WelcomeController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_not_rate_limited

    def show
      analytics.idv_doc_auth_welcome_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('welcome', :view, true)

      @presenter = Idv::WelcomePresenter.new(decorated_sp_session)
    end

    def update
      clear_future_steps!
      analytics.idv_doc_auth_welcome_submitted(**analytics_arguments)

      create_document_capture_session
      cancel_previous_in_person_enrollments

      idv_session.welcome_visited = true

      redirect_to idv_agreement_url
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :welcome,
        controller: self,
        next_steps: [:agreement],
        preconditions: ->(idv_session:, user:) { !user.gpo_verification_pending_profile? },
        undo_step: ->(idv_session:, user:) do
          idv_session.welcome_visited = nil
          idv_session.document_capture_session_uuid = nil
        end,
      )
    end

    private

    def analytics_arguments
      {
        step: 'welcome',
        analytics_id: 'Doc Auth',
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
