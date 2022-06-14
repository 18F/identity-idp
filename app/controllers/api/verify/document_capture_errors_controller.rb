module Api
  module Verify
    class DocumentCaptureErrorsController < BaseController
      include EffectiveUser

      self.required_step = nil

      before_action :verify_document_capture_session

      def delete
        document_capture_session.update(ocr_confirmation_pending: false)
        render json: {}
      end

      private

      def user_authenticated_for_api?
        !!effective_user
      end

      def verify_document_capture_session
        return if document_capture_session
        render_errors({ document_capture_session_uuid: ['Invalid document capture session' ] })
      end

      def document_capture_session
        return @document_capture_session if defined?(@document_capture_session)
        @document_capture_session = DocumentCaptureSession.find_by(
          uuid: document_capture_session_uuid,
        )
      end

      def document_capture_session_uuid
        params.require(:document_capture_session_uuid)
      end
    end
  end
end
