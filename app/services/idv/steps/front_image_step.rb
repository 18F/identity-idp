module Idv
  module Steps
    class FrontImageStep < DocAuthBaseStep
      def call
        success, instance_id_or_message, analytics_hash = assure_id_create_document
        return failure(instance_id_or_message, analytics_hash) unless success

        flow_session[:instance_id] = instance_id_or_message
        upload_front_image
      end

      private

      def assure_id_create_document
        rescue_network_errors { assure_id.create_document }
      end

      def form_submit
        Idv::ImageUploadForm.new.submit(permit(:image))
      end

      def upload_front_image
        success, message, analyics_hash = post_front_image
        return failure(message, analyics_hash) unless success
      end
    end
  end
end
