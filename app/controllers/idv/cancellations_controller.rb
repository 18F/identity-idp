module Idv
  class CancellationsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def new
      properties = ParseControllerFromReferer.new(request.referer).call
      analytics.track_event(Analytics::IDV_CANCELLATION, properties)
    end

    def destroy
      analytics.track_event(Analytics::IDV_CANCELLATION_CONFIRMED)
      idv_session = user_session[:idv]
      idv_session&.clear
      reset_doc_auth
    end

    private

    def reset_doc_auth
      user_session.delete('idv/doc_auth')
      user_session['idv'] = { params: {}, step_attempts: { phone: 0 } }
    end
  end
end
