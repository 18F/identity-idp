# frozen_string_literal: true

module DocAuth
  module LexisNexis
    class DdpClient
      attr_reader :config

      def initialize(attrs)
        @config = DocAuth::LexisNexis::DdpConfig.new(attrs)
        @config.validate!
      end

      # rubocop:disable Lint/UnusedMethodArgument
      def post_images(
        document_type_requested: nil,
        passport_requested: false,
        liveness_checking_required: false,
        front_image: nil,
        back_image: nil,
        passport_image: nil,
        selfie_image: nil,
        image_source: nil,
        images_cropped: false,
        uuid_prefix: nil,
        user_uuid: nil,
        user_email: nil
      )
        # rubocop:enable Lint/UnusedMethodArgument
        request_applicant = {
          front_image:,
          back_image:,
          passport_image:,
          selfie_image:,
          document_type_requested:,
          liveness_checking_required:,
          passport_requested:,
          uuid_prefix:,
          uuid: user_uuid,
          email: user_email,
        }
        Requests::Ddp::TrueIdRequest.new(
          config:,
          user_uuid:,
          uuid_prefix:,
          applicant: request_applicant,
        ).fetch
      end
    end
  end
end
