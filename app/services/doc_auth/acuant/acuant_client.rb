module DocAuth
  module Acuant
    class AcuantClient
      attr_reader :config

      def initialize(**config_keywords)
        @config = Config.new(**config_keywords)
      end

      # @see DocAuth::ImageSources
      def create_document(image_source:)
        raise "unknown image_source=#{image_source}" if !ImageSources::ALL.include?(image_source)

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

      def get_results(instance_id:)
        Requests::GetResultsRequest.new(config: config, instance_id: instance_id).fetch
      end

      # rubocop:disable Lint/UnusedMethodArgument
      def post_images(
        front_image:,
        back_image:,
        image_source:,
        liveness_checking_enabled: nil,
        user_uuid: nil,
        uuid_prefix: nil
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

        results_response
      end
      # rubocop:enable Lint/UnusedMethodArgument
    end
  end
end
