# frozen_string_literal: true

module Idv
  class WelcomeController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern
    include DocAuthVendorConcern
    include Idv::ChooseIdTypeConcern

    before_action :confirm_step_allowed
    before_action :confirm_not_rate_limited
    before_action :cancel_previous_in_person_enrollments, only: :show
    before_action :update_passport_allowed,
                  only: :show,
                  if: -> { IdentityConfig.store.doc_auth_passports_enabled }
    before_action :update_doc_auth_vendor

    def show
      idv_session.proofing_started_at ||= Time.zone.now.iso8601
      analytics.idv_doc_auth_welcome_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer])
        .call('welcome', :view, true)

      @presenter = Idv::WelcomePresenter.new(
        decorated_sp_session:,
        passport_allowed: idv_session.passport_allowed,
      )
    end

    def update
      clear_future_steps!
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
          idv_session.bucketed_doc_auth_vendor = nil
          idv_session.passport_allowed = nil
        end,
      )
    end

    private

    def analytics_arguments
      {
        step: 'welcome',
        analytics_id: 'Doc Auth',
        doc_auth_vendor: idv_session.bucketed_doc_auth_vendor,
        passport_allowed: idv_session.passport_allowed,
      }.merge(ab_test_analytics_buckets)
    end

    def create_document_capture_session
      document_capture_session = DocumentCaptureSession.create!(
        user_id: current_user.id,
        issuer: sp_session[:issuer],
        doc_auth_vendor:,
        passport_status:,
      )
      idv_session.document_capture_session_uuid = document_capture_session.uuid
    end

    def cancel_previous_in_person_enrollments
      UspsInPersonProofing::EnrollmentHelper.cancel_establishing_and_in_progress_enrollments(
        current_user,
      )
    end

    def update_doc_auth_vendor
      doc_auth_vendor
    end

    def update_passport_allowed
      if !IdentityConfig.store.doc_auth_passports_enabled ||
         resolved_authn_context_result.facial_match?
        idv_session.passport_allowed = nil
        return
      end

      idv_session.passport_allowed ||= begin
        if dos_passport_api_healthy?(analytics:)
          (ab_test_bucket(:DOC_AUTH_PASSPORT) == :passport_allowed)
        end
      end
    end

    def passport_status
      if resolved_authn_context_result.facial_match?
        idv_session.passport_allowed = nil
      end

      :allowed if idv_session.passport_allowed
    end
  end
end
