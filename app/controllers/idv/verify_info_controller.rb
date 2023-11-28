module Idv
  class VerifyInfoController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern
    include VerifyInfoConcern
    include Steps::ThreatMetrixStepHelper

    before_action :confirm_not_rate_limited_after_doc_auth, except: [:show]
    before_action :confirm_step_allowed
    before_action :confirm_verify_info_step_needed

    def show
      @step_indicator_steps = step_indicator_steps
      @ssn = idv_session.ssn
      @pii = pii

      analytics.idv_doc_auth_verify_visited(**analytics_arguments)
      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('verify', :view, true)

      @had_barcode_read_failure = idv_session.had_barcode_read_failure
      process_async_state(load_async_state)
    end

    def update
      clear_future_steps!
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
        controller: controller_name,
        next_steps: [:success], # [:phone],
        preconditions: ->(idv_session:, user:) do
          idv_session.ssn && idv_session.document_capture_complete?
        end,
        undo_step: ->(idv_session:, user:) do
          idv_session.resolution_successful = nil
          idv_session.address_edited = nil
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
      @pii = idv_session.pii_from_doc
    end
  end
end
