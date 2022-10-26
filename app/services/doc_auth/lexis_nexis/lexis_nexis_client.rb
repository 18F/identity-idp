module DocAuth
  module LexisNexis
    class LexisNexisClient
      attr_reader :config

      def initialize(**config_keywords)
        @config = Config.new(**config_keywords)
        @config.validate!
      end

      def create_document
        raise NotImplementedError
      end

      def post_front_image(image:, instance_id: nil)
        raise NotImplementedError
      end

      def post_back_image(image:, instance_id: nil)
        raise NotImplementedError
      end

      def get_results(instance_id:)
        raise NotImplementedError
      end

      def post_images(
        front_image:,
        back_image:,
        image_source: nil,
        user_uuid: nil,
        uuid_prefix: nil
      )
        Requests::TrueIdRequest.new(
          config: config,
          user_uuid: user_uuid,
          uuid_prefix: uuid_prefix,
          front_image: front_image,
          back_image: back_image,
          image_source: image_source,
        ).fetch
      end
    end
  end
end
