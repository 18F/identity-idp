module Idv
  class VerifyInfoController < ApplicationController
    include IdvStepConcern
    include StepUtilitiesConcern
    include StepIndicatorConcern
    include VerifyInfoConcern
    include Steps::ThreatMetrixStepHelper

    before_action :confirm_ssn_step_complete
    before_action :confirm_verify_info_step_needed

    def show
      @step_indicator_steps = step_indicator_steps

      analytics.idv_doc_auth_verify_visited(**analytics_arguments)
      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('verify', :view, true)

      if ssn_throttle.throttled?
        idv_failure_log_throttled(:proof_ssn)
        redirect_to idv_session_errors_ssn_failure_url
        return
      end

      if resolution_throttle.throttled?
        idv_failure_log_throttled(:idv_resolution)
        redirect_to throttled_url
        return
      end

      @had_barcode_read_failure = flow_session[:had_barcode_read_failure]
      process_async_state(load_async_state)
    end

    private

    def modify_pii_for_update
      pii[:uuid_prefix] = ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id
    end

    def after_update_url
      idv_verify_info_url
    end

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

    def delete_pii
      flow_session.delete(:pii_from_doc)
      flow_session.delete(:pii_from_user)
    end

    # copied from address_controller
    def confirm_ssn_step_complete
      return if pii.present? && pii[:ssn].present?
      redirect_to prev_url
    end
  end
end
