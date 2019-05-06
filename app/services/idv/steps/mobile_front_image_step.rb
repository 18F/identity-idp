module Idv
  module Steps
    class MobileFrontImageStep < DocAuthBaseStep
      def call
        success, instance_id_or_message = assure_id.create_document
        return failure(instance_id_or_message) unless success

        flow_session[:instance_id] = instance_id_or_message
        upload_front_image
      end

      private

      def form_submit
        Idv::ImageUploadForm.new.submit(permit(:image))
      end

      def upload_front_image
        success, message, analytics_hash = post_front_image
        return failure(message, analytics_hash) unless success
      end
    end
  end
end
