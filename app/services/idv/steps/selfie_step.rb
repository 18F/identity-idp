module Idv
  module Steps
    class SelfieStep < DocAuthBaseStep
      def call
        add_cost(:acuant_result) if results_response.to_h[:billed]
        if results_response.success?
          send_selfie_request
          results_response
        else
          handle_selfie_step_failure(results_response)
        end
      end

      private

      def send_selfie_request
        selfie_response = DocAuthClient.client.post_selfie(
          instance_id: instance_id, image: image.read,
        )
        if selfie_response.success?
          handle_successful_selfie_match
        else
          handle_selfie_step_failure(selfie_response)
        end
      end

      def handle_successful_selfie_match
        save_proofing_components

        if user_id_from_token.present?
          CaptureDoc::UpdateAcuantToken.call(user_id_from_token, flow_session[:instance_id])
        else
          extract_pii_from_doc(results_response)
        end
      end

      def handle_selfie_step_failure(failure_response)
        if mobile?
          mark_step_incomplete(:mobile_front_image)
          mark_step_incomplete(:mobile_back_image)
          mark_step_incomplete(:capture_mobile_back_image)
        else
          mark_step_incomplete(:front_image)
          mark_step_incomplete(:back_image)
        end
        Funnel::DocAuth::LogDocumentError.call(user_id, failure_response&.result_code&.name.to_s)
        failure(failure_response.errors.first, failure_response.to_h)
      end

      def results_response
        @results_response ||= DocAuthClient.client.get_results(
          instance_id: flow_session[:instance_id],
        )
      end

      def form_submit
        Idv::ImageUploadForm.new.submit(permit(:image, :image_data_url))
      end

      def instance_id
        flow_session[:instance_id]
      end
    end
  end
end
