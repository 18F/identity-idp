require 'identity_doc_auth/acuant/config'
require 'identity_doc_auth/acuant/requests/create_document_request'
require 'identity_doc_auth/acuant/requests/upload_image_request'
require 'identity_doc_auth/acuant/requests/get_face_image_request'
require 'identity_doc_auth/acuant/requests/facial_match_request'
require 'identity_doc_auth/acuant/requests/liveness_request'
require 'identity_doc_auth/acuant/requests/get_results_request'

module IdentityDocAuth
  module Acuant
    class AcuantClient
      attr_reader :config

      def initialize(**config_keywords)
        @config = Config.new(**config_keywords)
      end

      # @see IdentityDocAuth::ImageSources
      def create_document(image_source:)
        if !ImageSources::ALL.include?(image_source)
          raise "unknown image_source=#{image_source}"
        end

        Requests::CreateDocumentRequest.new(config: config, image_source: image_source).fetch
      end

      def post_front_image(image:, instance_id:)
        Requests::UploadImageRequest.new(
          config: config,
          instance_id: instance_id,
          image_data: image,
          side: :front,
        ).fetch
      end

      def post_back_image(image:, instance_id:)
        Requests::UploadImageRequest.new(
          config: config,
          instance_id: instance_id,
          image_data: image,
          side: :back,
        ).fetch
      end

      def post_selfie(image:, instance_id:)
        get_face_image_response = Requests::GetFaceImageRequest.new(
          config: config,
          instance_id: instance_id
        ).fetch
        return get_face_image_response unless get_face_image_response.success?

        facial_match_response = Requests::FacialMatchRequest.new(
          config: config,
          selfie_image: image,
          document_face_image: get_face_image_response.image,
        ).fetch
        liveness_response = Requests::LivenessRequest.new(config: config, image: image).fetch

        facial_match_response.merge(liveness_response)
      end

      def get_results(instance_id:)
        Requests::GetResultsRequest.new(config: config, instance_id: instance_id).fetch
      end

      def post_images(
        front_image:,
        back_image:,
        selfie_image:,
        image_source:,
        liveness_checking_enabled: nil
      )
        document_response = create_document(image_source: image_source)
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
