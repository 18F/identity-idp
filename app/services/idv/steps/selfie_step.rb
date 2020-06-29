module Idv
  module Steps
    class SelfieStep < DocAuthBaseStep
      def call
        selfie_response = acuant_client.post_selfie(instance_id: instance_id, image: image.read)
        if selfie_response.success?
          return unless user_id_from_token
          CaptureDoc::UpdateAcuantToken.call(user_id_from_token, flow_session[:instance_id])
        else
          selfie_failure(selfie_response)
        end
      end

      private

      def form_submit
        Idv::ImageUploadForm.new.submit(permit(:image, :image_data_url))
      end

      def instance_id
        flow_session[:instance_id]
      end

      def selfie_failure(selfie_response)
        if mobile?
          mark_step_incomplete(:mobile_front_image)
          mark_step_incomplete(:mobile_back_image)
          mark_step_incomplete(:capture_mobile_back_image)
        else
          mark_step_incomplete(:front_image)
          mark_step_incomplete(:back_image)
        end
        failure(selfie_response.errors.first, selfie_response.to_h)
      end
    end
  end
end
