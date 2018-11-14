module Idv
  module Steps
    class FrontImageStep < DocAuthBaseStep
      def call
        success, instance_id_or_message = assure_id.create_document
        return failure(instance_id_or_message) unless success

        flow_session[:instance_id] = instance_id_or_message
        upload_front_image
      end

      private

      def form_submit
        Idv::ImageUploadForm.new(current_user).submit(permit(:image))
      end

      def upload_front_image
        success, message = assure_id.post_front_image(image.read)
        return failure(message) unless success
      end
    end
  end
end
