module Api
  module Verify
    class DocumentCaptureErrorsController < BaseController
      include EffectiveUser

      self.required_step = nil

      def delete
        form = DocumentCaptureErrorsDeleteForm.new(
          document_capture_session_uuid: params[:document_capture_session_uuid],
        )
        result, document_capture_session = form.submit

        if result.success?
          document_capture_session.update(ocr_confirmation_pending: false)
          render json: {}
        else
          render json: { errors: result.errors }, status: :bad_request
        end
      end

      private

      def user_authenticated_for_api?
        !!effective_user
      end
    end
  end
end
