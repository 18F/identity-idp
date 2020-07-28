module Idv
  module Steps
    class CaptureMobileBackImageStep < DocAuthBaseStep
      def call
        back_image_response = post_back_image
        if back_image_response.success?
          fetch_doc_auth_results_or_redirect_to_selfie
        else
          failure(back_image_response.errors.first, back_image_response.to_h)
        end
      end

      private

      def fetch_doc_auth_results_or_redirect_to_selfie
        # If liveness checking is enabled, we will wait until the selfie check
        # to get the results. If there will not be a selfie check we need to
        # validate them here before continuing.
        return if liveness_checking_enabled?

        get_results_response = DocAuthClient.client.get_results(instance_id:
                                                                    flow_session[:instance_id])
        if get_results_response.success?
          mark_step_complete(:selfie)
          CaptureDoc::UpdateAcuantToken.call(user_id_from_token, flow_session[:instance_id])
        else
          handle_document_verification_failure(get_results_response)
        end
      end

      def handle_document_verification_failure(get_results_response)
        mark_step_incomplete(:mobile_front_image)
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
