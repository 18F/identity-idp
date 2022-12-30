module Idv
  class VerifyPiiController < ApplicationController
    include StepIndicatorConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_pii_from_doc

    def show
      local_params = {
        pii: pii,
        step_url: method(:idv_doc_auth_step_url),
        step_indicator: step_indicator_params,
        step_template: 'idv/doc_auth/verify',
        flow_namespace: 'idv',
        flow_session: flow_session,
      }

      render template: 'layouts/flow_step', locals: local_params
    end

    # copied from doc_auth_controller
    def flow_session
      user_session['idv/doc_auth']
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
    def confirm_pii_from_doc
      @pii = user_session.dig('idv/doc_auth', 'pii_from_doc')
      return if @pii.present?
      redirect_to idv_doc_auth_url
    end
  end
end
