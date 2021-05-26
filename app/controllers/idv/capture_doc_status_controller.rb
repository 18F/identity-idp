module Idv
  class CaptureDocStatusController < ApplicationController
    before_action :confirm_two_factor_authenticated

    respond_to :json

    def show
      render document_capture_session_poll_render_result
    end

    private

    def document_capture_session_poll_render_result
      return { json: nil, status: :unauthorized } if !flow_session || !document_capture_session
      return { json: nil, status: :gone } if document_capture_session.cancelled_at
      return {
        json: { redirect: idv_session_errors_throttled_url },
        status: :too_many_requests,
      } if is_throttled

      result = document_capture_session.load_result ||
               document_capture_session.load_doc_auth_async_result

      return { json: nil, status: :accepted } if result.blank?
      return { json: nil, status: :unauthorized } unless result.success?
      { json: nil, status: :ok }
    end

    def flow_session
      user_session['idv/doc_auth']
    end

    def document_capture_session
      return @document_capture_session if defined?(@document_capture_session)
      session_uuid = flow_session[:document_capture_session_uuid]
      @document_capture_session = DocumentCaptureSession.find_by(uuid: session_uuid)
    end

    def is_throttled
      Throttler::IsThrottled.call(document_capture_session.user_id, :idv_acuant)
    end
  end
end
