require 'identity_doc_auth/lexis_nexis/config'
require 'identity_doc_auth/lexis_nexis/request'
require 'identity_doc_auth/lexis_nexis/requests/true_id_request'
require 'identity_doc_auth/lexis_nexis/responses/lexis_nexis_response'
require 'identity_doc_auth/lexis_nexis/responses/true_id_response'

module IdentityDocAuth
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

      def post_selfie(image:, instance_id: nil)
        raise NotImplementedError
      end

      def get_results(instance_id:)
        raise NotImplementedError
      end

      def post_images(
        front_image:,
        back_image:,
        selfie_image:,
        liveness_checking_enabled: nil,
        image_source: nil
      )
        Requests::TrueIdRequest.new(
          config: config,
          front_image: front_image,
          back_image: back_image,
          selfie_image: selfie_image,
          liveness_checking_enabled: liveness_checking_enabled,
        ).fetch
      end
    end
  end
end
