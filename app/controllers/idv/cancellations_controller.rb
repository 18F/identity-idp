module Idv
  class CancellationsController < ApplicationController
    include IdvSession
    include GoBackHelper

    before_action :confirm_idv_needed

    def new
      properties = ParseControllerFromReferer.new(request.referer).call
      analytics.track_event(Analytics::IDV_CANCELLATION, properties.merge(step: params[:step]))
      @go_back_path = go_back_path || idv_path
      @hybrid_session = hybrid_session?
    end

    def destroy
      analytics.track_event(Analytics::IDV_CANCELLATION_CONFIRMED, step: params[:step])
      @return_to_sp_path = return_to_sp_failure_to_proof_path(location_params)
      @hybrid_session = hybrid_session?
      if hybrid_session?
        cancel_document_capture_session
      else
        idv_session = user_session[:idv]
        idv_session&.clear
        reset_doc_auth
      end
    end

    private

    def location_params
      params.permit(:step, :location).to_h.symbolize_keys
    end

    def reset_doc_auth
      user_session.delete('idv/doc_auth')
      user_session['idv'] = {}
    end

    def cancel_document_capture_session
      document_capture_session&.update(cancelled_at: Time.zone.now)
    end

    def document_capture_session_uuid
      session[:document_capture_session_uuid]
    end

    def document_capture_session
      DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
    end
  end
end
