module Idv
  module Steps
    class BackImageStep < DocAuthBaseStep
      def call
        back_image_response = post_back_image
        if back_image_response.success?
          fetch_doc_auth_results
        else
          failure(back_image_response.errors.first, back_image_response.to_h)
        end
      end

      private

      def fetch_doc_auth_results
        get_results_response = doc_auth_client.get_results(instance_id: flow_session[:instance_id])
        if get_results_response.success?
          mark_selfie_step_complete_unless_liveness_checking_is_enabled
          save_proofing_components
          extract_pii_from_doc(get_results_response)
        else
          handle_document_verification_failure(get_results_response)
        end
      end

      def handle_document_verification_failure(get_results_response)
        mark_step_incomplete(:front_image)
        extra = get_results_response.to_h.merge(
          notice: I18n.t('errors.doc_auth.general_info'),
        )
        failure(get_results_response.errors.first, extra)
      end

      def form_submit
        Idv::ImageUploadForm.new.submit(permit(:image, :image_data_url))
      end
    end
  end
end
