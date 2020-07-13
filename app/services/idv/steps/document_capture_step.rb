module Idv
  module Steps
    class DocumentCaptureStep < DocAuthBaseStep
      def call
        create_document_response = doc_auth_client.create_document
        if create_document_response.success?
          flow_session[:instance_id] = create_document_response.instance_id
          upload_images
        else
          failure(create_document_response.errors.first, create_document_response.to_h)
        end
      end

      private

      def upload_images
        response = post_images
        if response.success?
          fetch_doc_auth_results
        else
          failure(response.errors.first, response.to_h)
        end
      end

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
        Idv::DocumentCaptureForm.new.submit(permit(:front_image, :front_image_data_url,
                                                   :back_image, :back_image_data_url))
      end
    end
  end
end
