module Idv
  module Steps
    class DocumentCaptureStep < DocAuthBaseStep
      def call
        create_document_response = doc_auth_client.create_document

        if create_document_response.success?
          flow_session[:instance_id] = create_document_response.instance_id
          upload_images
        else
          failure(create_document_response.errors.first, create_document_response.to_h)
        end
      end

      def form_submit
        Idv::DocumentCaptureForm.new.submit(permit(:front_image, :front_image_data_url,
                                                   :back_image, :back_image_data_url))
      end

      def upload_images
        response = post_images
        failure(response.errors.first, response.to_h) unless response.success?
      end
    end
  end
end
