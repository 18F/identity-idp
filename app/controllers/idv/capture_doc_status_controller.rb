module Idv
  class CaptureDocStatusController < ApplicationController
    before_action :confirm_two_factor_authenticated

    respond_to :json

    def show
      result = if FeatureManagement.document_capture_step_enabled?
                 document_capture_session_poll_render_result
               else
                 doc_capture_poll_render_result
               end

      render result
    end

    private

    def doc_capture_poll_render_result
      doc_capture = DocCapture.find_by(user_id: current_user.id)
      return { plain: 'Unauthorized', status: :unauthorized } if doc_capture.blank?
      return { plain: 'Pending', status: :accepted } if doc_capture.acuant_token.blank?
      { plain: 'Complete', status: :ok }
    end

    def document_capture_session_poll_render_result
      session_uuid = flow_session[:document_capture_session_uuid]
      document_capture_session = DocumentCaptureSession.find_by(uuid: session_uuid)
      return { plain: 'Unauthorized', status: :unauthorized } unless document_capture_session

      result = document_capture_session.load_result
      return { plain: 'Pending', status: :accepted } if result.blank?
      return { plain: 'Unauthorized', status: :unauthorized } unless result.success?
      { plain: 'Complete', status: :ok }
    end

    def flow_session
      user_session['idv/doc_auth']
    end
  end
end
