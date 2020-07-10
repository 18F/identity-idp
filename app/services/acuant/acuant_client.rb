module Acuant
  class AcuantClient
    def create_document
      Requests::CreateDocumentRequest.new.fetch
    end

    def post_front_image(image:, instance_id:)
      result = Requests::UploadImageRequest.new(
        instance_id: instance_id,
        image_data: image,
        side: :front,
      ).fetch
      result
    end

    def post_back_image(image:, instance_id:)
      Requests::UploadImageRequest.new(
        instance_id: instance_id,
        image_data: image,
        side: :back,
      ).fetch
    end

    def post_images(front_image:, back_image:, instance_id:)
      front_response = post_front_image(image: front_image, instance_id: instance_id)
      back_response = post_back_image(image: back_image, instance_id: instance_id)

      Acuant::Response.new(
        success: front_response.success? && back_response.success?,
        errors: (front_response.errors || []) + (back_response.errors || []),
        exception: front_response.exception || back_response.exception,
        extra: { front_response: front_response, back_response: back_response },
      )
    end

    def get_results(instance_id:)
      Requests::GetResultsRequest.new(instance_id: instance_id).fetch
    end

    def post_selfie(instance_id:, image:)
      get_face_image_response = Requests::GetFaceImageRequest.new(instance_id: instance_id).fetch
      return get_face_image_response unless get_face_image_response.success?

      facial_match_response = Requests::FacialMatchRequest.new(
        selfie_image: image,
        document_face_image: get_face_image_response.image,
      ).fetch
      liveness_response = Requests::LivenessRequest.new(image: image).fetch

      merge_facial_match_and_liveness_response(facial_match_response, liveness_response)
    end

    private

    def merge_facial_match_and_liveness_response(facial_match_response, liveness_response)
      Acuant::Response.new(
        success: facial_match_response.success? && liveness_response.success?,
        errors: facial_match_response.errors + liveness_response.errors,
        exception: facial_match_response.exception || liveness_response.exception,
        extra: {
          facial_match_response: facial_match_response.to_h,
          liveness_response: liveness_response.to_h,
        },
      )
    end
  end
end
