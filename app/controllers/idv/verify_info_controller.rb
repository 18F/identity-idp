# frozen_string_literal: true

module Idv
  class VerifyInfoController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern
    include VerifyInfoConcern
    include Steps::ThreatMetrixStepHelper

    before_action :confirm_not_rate_limited_after_doc_auth, except: [:show]
    before_action :log_event_for_missing_threatmetrix_session_id
    before_action :confirm_step_allowed

    def show
      @step_indicator_steps = step_indicator_steps
      @ssn = idv_session.ssn
      @pii = pii

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer])
        .call('verify', :view, true)

      @had_barcode_read_failure = idv_session.had_barcode_read_failure
      process_async_state(load_async_state)
    end

    def update
      clear_future_steps!
      idv_session.invalidate_verify_info_step!
      success = shared_update

      if success
        # Don't allow the user to go back to document capture after verifying
        if idv_session.redo_document_capture
          idv_session.redo_document_capture = nil
          idv_session.flow_path ||= 'standard'
        end

        redirect_to idv_verify_info_url
      end
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :verify_info,
        controller: self,
        next_steps: [:phone, :request_letter],
        preconditions: ->(idv_session:, user:) do
          idv_session.remote_document_capture_complete? &&
            idv_session.ssn_step_complete? &&
              threatmetrix_session_id_present_or_not_required?(idv_session:)
        end,
        undo_step: ->(idv_session:, user:) do
          idv_session.residential_resolution_vendor = nil
          idv_session.resolution_successful = nil
          idv_session.resolution_vendor = nil
          idv_session.source_check_vendor = nil
          idv_session.address_edited = nil
          idv_session.verify_info_step_document_capture_session_uuid = nil
          idv_session.threatmetrix_review_status = nil
          idv_session.applicant = nil
          idv_session.phone_precheck_successful = nil
          idv_session.invalidate_phone_step!
        end,
      )
    end

    private

    def flow_param; end

    def prev_url
      idv_ssn_url
    end

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'verify',
        analytics_id: 'Doc Auth',
      }.merge(ab_test_analytics_buckets)
    end

    def pii
      idv_session.pii_from_doc.to_h.merge(
        ssn: idv_session.ssn,
        consent_given_at: idv_session.idv_consent_given_at,
        **idv_session.updated_user_address.to_h,
      ).with_indifferent_access
    end
  end
end
