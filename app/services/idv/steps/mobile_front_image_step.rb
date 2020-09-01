module Idv
  module Steps
    class MobileFrontImageStep < DocAuthBaseStep
      def call
        create_document_response = DocAuth::Client.client.create_document

        if create_document_response.success?
          flow_session[:instance_id] = create_document_response.instance_id
          upload_front_image
        else
          failure(create_document_response.errors.values.flatten.join(' '), create_document_response.to_h)
        end
      end

      private

      def form_submit
        Idv::ImageUploadForm.new.submit(permit(:image, :image_data_url))
      end

      def upload_front_image
        response = post_front_image
        failure(response.errors.values.flatten.join(' '), response.to_h) unless response.success?
      end
    end
  end
end
