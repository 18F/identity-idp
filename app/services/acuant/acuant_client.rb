module Acuant
  class AcuantClient
    def create_document
      Requests::CreateDocumentRequest.new.fetch
    end

    def post_front_image(image:, instance_id:)
      Requests::UploadImageRequest.new(
        instance_id: instance_id,
        image_data: image,
        side: :front,
      ).fetch
    end

    def post_back_image(image:, instance_id:)
      Requests::UploadImageRequest.new(
        instance_id: instance_id,
        image_data: image,
        side: :back,
      ).fetch
    end

    def get_results(instance_id:)
      Requests::GetResultsRequest.new(instance_id: instance_id).fetch
    end
  end
end
