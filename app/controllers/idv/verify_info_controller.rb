module Idv
  class VerifyInfoController < ApplicationController
    include StepIndicatorConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_ssn_step_complete

    def analytics_visited_event
      :idv_doc_auth_verify_visited
    end

    def show
      analytics.public_send(
        analytics_visited_event, **analytics_arguments
      )

      local_params = {
        pii: pii,
        step_url: method(:idv_doc_auth_step_url),
        step_indicator: step_indicator_params,
        step_template: 'idv/doc_auth/verify',
        flow_namespace: 'idv',
        flow_session: flow_session,
      }

      render :show, locals: local_params
    end

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'verify',
        step_count: 1,
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing,
      }.merge(**extra_analytics_properties)
    end

    # copied from doc_auth_controller
    def flow_session
      user_session['idv/doc_auth']
    end

    def flow_path
      flow_session[:flow_path]
    end

    def irs_reproofing
      effective_user&.decorate&.reproof_for_irs?(
        service_provider: current_sp,
      ).present?
    end

    # Copied from capture_doc_flow.rb
    # and from doc_auth_flow.rb
    def extra_analytics_properties
      capture_session_uuid = flow_session[:document_capture_session_uuid]
      if capture_session_uuid
        {
          acuant_sdk_upgrade_ab_test_bucket:
          AbTests::ACUANT_SDK.bucket(capture_session_uuid),
        }
      else
        {}
      end
    end

    # copied from verify_step
    def pii
      flow_session[:pii_from_doc]
    end

    # modified from flow_state_machine
    def step_indicator_params
      {
        steps: Flows::DocAuthFlow::STEP_INDICATOR_STEPS,
        current_step: :verify_info,
      }
    end

    # copied from address_controller
    def confirm_ssn_step_complete
      @pii = user_session.dig('idv/doc_auth', 'pii_from_doc')
      return if @pii.present?
      redirect_to idv_doc_auth_url
    end
  end
end
