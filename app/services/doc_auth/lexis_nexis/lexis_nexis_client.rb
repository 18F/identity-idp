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

      def post_images(
        front_image:,
        back_image:,
        image_source: nil,
        user_uuid: nil,
        uuid_prefix: nil
      )
        Requests::TrueIdRequest.new(
          config:,
          user_uuid:,
          uuid_prefix:,
          front_image:,
          back_image:,
          image_source:,
        ).fetch
      end
    end
  end
end
