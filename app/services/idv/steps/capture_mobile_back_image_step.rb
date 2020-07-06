module Idv
  module Steps
    class CaptureMobileBackImageStep < DocAuthBaseStep
      def call
        back_image_response = post_back_image
        if back_image_response.success?
          handle_back_image_success
        else
          failure(back_image_response.errors.first, back_image_response.to_h)
        end
      end

      private

      def handle_back_image_success
        return if liveness_checking_enabled?

        mark_step_complete(:selfie)
        CaptureDoc::UpdateAcuantToken.call(user_id_from_token, flow_session[:instance_id])
      end

      def form_submit
        Idv::ImageUploadForm.new.submit(permit(:image, :image_data_url))
      end
    end
  end
end
