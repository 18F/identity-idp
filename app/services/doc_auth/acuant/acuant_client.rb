module DocAuth
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

      def post_selfie(image:, instance_id:)
        get_face_image_response = Requests::GetFaceImageRequest.new(instance_id: instance_id).fetch
        return get_face_image_response unless get_face_image_response.success?

        facial_match_response = Requests::FacialMatchRequest.new(
          selfie_image: image,
          document_face_image: get_face_image_response.image,
        ).fetch
        liveness_response = Requests::LivenessRequest.new(image: image).fetch

        facial_match_response.merge(liveness_response)
      end

      def get_results(instance_id:)
        Requests::GetResultsRequest.new(instance_id: instance_id).fetch
      end

      def post_images(front_image:, back_image:, selfie_image:, liveness_checking_enabled: nil)
        document_response = create_document
        return document_response unless document_response.success?

        instance_id = document_response.instance_id

        front_image_response = post_front_image(image: front_image, instance_id: instance_id)
        return front_image_response unless front_image_response.success?

        back_image_response = post_back_image(image: back_image, instance_id: instance_id)
        return back_image_response unless back_image_response.success?

        results_response = get_results(instance_id: instance_id)
        return results_response unless results_response.success?

        if liveness_checking_enabled
          post_selfie(image: selfie_image, instance_id: instance_id).merge(results_response)
        else
          results_response
        end
      end
    end
  end
end
