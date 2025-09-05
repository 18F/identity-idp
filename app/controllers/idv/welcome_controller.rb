# frozen_string_literal: true

module Idv
  class WelcomeController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern
    include Idv::ChooseIdTypeConcern

    before_action :confirm_step_allowed
    before_action :confirm_not_rate_limited
    before_action :cancel_previous_in_person_enrollments, only: :show

    def show
      analytics.idv_doc_auth_welcome_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer])
        .call('welcome', :view, true)

      @presenter = Idv::WelcomePresenter.new(
        decorated_sp_session:,
      )
    end

    def update
      clear_future_steps!
      idv_session.clear
      idv_session.proofing_started_at ||= Time.zone.now.iso8601
      create_document_capture_session
      analytics.idv_doc_auth_welcome_submitted(**analytics_arguments)
      idv_session.welcome_visited = true

      redirect_to idv_agreement_url
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :welcome,
        controller: self,
        next_steps: [:agreement],
        preconditions: ->(idv_session:, user:) { true },
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
      document_capture_session = DocumentCaptureSession.create!(
        user_id: current_user.id,
        issuer: sp_session[:issuer],
      )
      idv_session.document_capture_session_uuid = document_capture_session.uuid
    end

    def cancel_previous_in_person_enrollments
      UspsInPersonProofing::EnrollmentHelper.cancel_establishing_and_in_progress_enrollments(
        current_user,
      )
    end
  end
end
