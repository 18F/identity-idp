module DocAuth
  module LexisNexis
    class LexisNexisClient
      def create_document
        raise NotImplementedError
      end

      def post_front_image(image:, instance_id: nil)
        raise NotImplementedError
      end

      def post_back_image(image:, instance_id: nil)
        raise NotImplementedError
      end

      def post_selfie(image:, instance_id: nil)
        raise NotImplementedError
      end

      def get_results(instance_id:)
        raise NotImplementedError
      end

      def post_images(front_image:, back_image:, selfie_image:, liveness_checking_enabled: nil)
        Requests::TrueIdRequest.new(
          front_image: front_image,
          back_image: back_image,
          selfie_image: selfie_image,
          liveness_checking_enabled: liveness_checking_enabled,
        ).fetch
      end
    end
  end
end
