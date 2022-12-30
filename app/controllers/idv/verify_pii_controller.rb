module Idv
  class VerifyPiiController < ApplicationController
    include StepIndicatorConcern

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
  end
end
