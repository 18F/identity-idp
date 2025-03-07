# frozen_string_literal: true

module DocAuth
  module LexisNexis
    class LexisNexisClient
      attr_reader :config

      def initialize(**config_keywords)
        @config = Config.new(**config_keywords)
        @config.validate!
      end

      def post_images(
        front_image:,
        back_image:,
        document_type:,
        selfie_image: nil,
        image_source: nil,
        images_cropped: false,
        user_uuid: nil,
        uuid_prefix: nil,
        liveness_checking_required: false
      )
        Requests::TrueIdRequest.new(
          config: config,
          user_uuid: user_uuid,
          uuid_prefix: uuid_prefix,
          front_image: front_image,
          back_image: back_image,
          selfie_image: selfie_image,
          image_source: image_source,
          images_cropped: images_cropped,
          liveness_checking_required: liveness_checking_required,
          document_type: document_type,
        ).fetch
      end
    end
  end
end
