module Idv
  module Steps
    class CaptureMobileBackImageStep < DocAuthBaseStep
      def call
        good, data = assure_id.post_back_image(image.read)
        return failure(data) unless good

        failure_data, _data = verify_back_image(reset_step: :mobile_front_image)
        return failure_data if failure_data

        CaptureDoc::UpdateAcuantToken.call(user_id_from_token, flow_session[:instance_id])
      end

      private

      def form_submit
        Idv::ImageUploadForm.new.submit(permit(:image))
      end
    end
  end
end
