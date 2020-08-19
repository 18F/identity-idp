module Idv
  module Steps
    class DocumentCaptureStep < DocAuthBaseStep
      IMAGE_UPLOAD_PARAM_NAMES = %i[
        front_image back_image selfie_image front_image_data_url back_image_data_url
        selfie_image_data_url
      ].freeze

      def call
        if request_includes_images?
          post_images_and_handle_result
        else
          handle_stored_response
        end
      end

      private

      def post_images_and_handle_result
        response = post_images
        if response.success?
          save_proofing_components
          extract_pii_from_doc(response)
          response
        else
          handle_document_verification_failure(response)
        end
      end

      def handle_document_verification_failure(response)
        mark_step_incomplete(:document_capture)
        notice = if liveness_checking_enabled?
                   { notice: I18n.t('errors.doc_auth.document_capture_info_with_selfie_html') }
                 else
                   { notice: I18n.t('errors.doc_auth.document_capture_info_html') }
                 end
        log_document_error(response)
        extra = response.to_h.merge(notice)
        failure(response.errors.first, extra)
      end

      def handle_stored_response
        stored_result = document_capture_session&.load_result
        if stored_result.present? && stored_result.success?
          extract_pii_from_doc(stored_result)
        else
          extra = { stored_result_present: stored_result.present? }
          failure(I18n.t('errors.doc_auth.acuant_network_error'), extra)
        end
      end

      def request_includes_images?
        params.key?('doc_auth')
      end

      def form_submit
        return FormResponse.new(success: true, errors: {}) unless request_includes_images?

        Idv::DocumentCaptureForm.
          new(liveness_checking_enabled: liveness_checking_enabled?).
          submit(permit(IMAGE_UPLOAD_PARAM_NAMES))
      end
    end
  end
end
