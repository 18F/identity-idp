module Idv
  module Steps
    class DocumentCaptureStep < DocAuthBaseStep
      def call
        api_upload = user_session['idv/doc_auth']['api_upload']
        response = api_upload['documents'] || post_images(front_image.read, back_image.read)
        handle_response(response)
      end

      private

      def handle_response(response)
        if response.success?
          save_proofing_components
          extract_pii_from_doc(response)
        else
          handle_document_verification_failure(response)
        end
      end

      def handle_document_verification_failure(response)
        mark_step_incomplete(:document_capture)
        extra = response.to_h.merge(
          notice: I18n.t('errors.doc_auth.general_info'),
        )
        failure(response.errors.first, extra)
      end

      def form_submit
        Idv::DocumentCaptureForm.new.submit(permit(:front_image, :front_image_data_url,
                                                   :back_image, :back_image_data_url))
      end
    end
  end
end
