module Idv
  module Steps
    class BackImageStep < DocAuthBaseStep
      def call
        good, data, analytics_hash = post_back_image
        return failure(data, analytics_hash) unless good

        failure_data, data = verify_back_image(reset_step: :front_image)
        return failure_data if failure_data

        mark_selfie_step_complete_unless_liveness_checking_is_enabled

        extract_pii_from_doc(data)
      end

      private

      def form_submit
        Idv::ImageUploadForm.new.submit(permit(:image, :image_data_url))
      end
    end
  end
end
