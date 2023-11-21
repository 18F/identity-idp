module Idv
  class VerifyInfoController < ApplicationController
    include IdvStepConcern
    include StepIndicatorConcern
    include VerifyInfoConcern
    include Steps::ThreatMetrixStepHelper

    before_action :confirm_not_rate_limited_after_doc_auth, except: [:show]
    before_action :confirm_step_allowed

    def show
      @step_indicator_steps = step_indicator_steps
      @ssn = idv_session.ssn_or_applicant_ssn
      @pii = pii

      analytics.idv_doc_auth_verify_visited(**analytics_arguments)
      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('verify', :view, true)

      @had_barcode_read_failure = idv_session.had_barcode_read_failure
      process_async_state(load_async_state)
    end

    def update
      clear_future_steps!
      clear_current_step!
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
        next_steps: [:phone],
        preconditions: ->(idv_session:, user:) do
          idv_session.ssn_step_complete? && idv_session.remote_document_capture_complete?
        end,
        undo_step: ->(idv_session:, user:) do
          idv_session.resolution_successful = nil
          idv_session.address_edited = nil
          idv_session.verify_info_step_document_capture_session_uuid = nil
          idv_session.threatmetrix_review_status = nil
          idv_session.restore_pii_from_doc
        end,
      )
    end

    private

    def flow_param; end

    # state ID type isn't manually set for Idv::VerifyInfoController
    def set_state_id_type; end

    def prev_url
      idv_ssn_url
    end

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'verify',
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(ab_test_analytics_buckets)
    end

    def pii
      idv_session.pii_from_doc_or_applicant
    end
  end
end
