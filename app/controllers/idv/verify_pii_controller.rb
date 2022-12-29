module Idv
  class VerifyPiiController < ApplicationController
    # TODO Verify needed
    include StepIndicatorConcern

    def show
      local_params = {
        pii: pii,
        step_url: method(:idv_doc_auth_step_url),
        step_template: "idv/doc_auth/verify",
        flow_session: flow_session
      }
      puts "HELLOO!!!!"
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

  end
end
