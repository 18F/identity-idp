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
        selfie_image: nil,
        image_source: nil,
        user_uuid: nil,
        uuid_prefix: nil,
        liveness_checking_enabled: false
      )
        Requests::TrueIdRequest.new(
          config: config,
          user_uuid: user_uuid,
          uuid_prefix: uuid_prefix,
          front_image: front_image,
          back_image: back_image,
          selfie_image: selfie_image,
          image_source: image_source,
          liveness_checking_enabled: liveness_checking_enabled,
        ).fetch
      end
    end
  end
end
