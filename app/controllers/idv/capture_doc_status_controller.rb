module Idv
  class CaptureDocStatusController < ApplicationController
    before_action :confirm_two_factor_authenticated

    respond_to :json

    def show
      render document_capture_session_poll_render_result
    end

    private

    def document_capture_session_poll_render_result
      return { plain: 'Unauthorized', status: :unauthorized } unless flow_session
      session_uuid = flow_session[:document_capture_session_uuid]
      document_capture_session = DocumentCaptureSession.find_by(uuid: session_uuid)
      return { plain: 'Unauthorized', status: :unauthorized } unless document_capture_session

      result = document_capture_session.load_result ||
               document_capture_session.load_doc_auth_async_result

      return { plain: 'Pending', status: :accepted } if result.blank?
      return { plain: 'Unauthorized', status: :unauthorized } unless result.success?
      { plain: 'Complete', status: :ok }
    end

    def flow_session
      user_session['idv/doc_auth']
    end
  end
end
