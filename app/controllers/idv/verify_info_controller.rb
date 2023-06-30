module Idv
  class VerifyInfoController < ApplicationController
    include IdvStepConcern
    include StepUtilitiesConcern
    include StepIndicatorConcern
    include VerifyInfoConcern
    include Steps::ThreatMetrixStepHelper

    before_action :confirm_ssn_step_complete
    before_action :confirm_verify_info_step_needed
    skip_before_action :confirm_not_rate_limited, only: :show

    def show
      @step_indicator_steps = step_indicator_steps

      analytics.idv_doc_auth_verify_visited(**analytics_arguments)
      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('verify', :view, true)

      @had_barcode_read_failure = flow_session[:had_barcode_read_failure]
      process_async_state(load_async_state)
    end

    def update
      success = shared_update

      if success
        # Don't allow the user to go back to document capture after verifying
        if flow_session['redo_document_capture']
          flow_session.delete('redo_document_capture')
          idv_session.flow_path ||= 'standard'
        end

        redirect_to idv_verify_info_url
      end
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
      }.merge(**acuant_sdk_ab_test_analytics_args)
    end

    # copied from verify_step
    def pii
      @pii = flow_session[:pii_from_doc]
    end
  end
end
