module Idv
  class CancellationsController < ApplicationController
    include IdvSession
    include GoBackHelper

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def new
      properties = ParseControllerFromReferer.new(request.referer).call
      analytics.track_event(Analytics::IDV_CANCELLATION, properties.merge(step: params[:step]))
      @go_back_path = go_back_path || idv_path
    end

    def destroy
      analytics.track_event(Analytics::IDV_CANCELLATION_CONFIRMED, step: params[:step])
      idv_session = user_session[:idv]
      idv_session&.clear
      @return_to_sp_path = return_to_sp_failure_to_proof_path(location_params)
      reset_doc_auth
    end

    private

    def location_params
      params.permit(:step, :location).to_h.symbolize_keys
    end

    def reset_doc_auth
      user_session.delete('idv/doc_auth')
      user_session['idv'] = { params: {}, step_attempts: { phone: 0 } }
    end
  end
end
