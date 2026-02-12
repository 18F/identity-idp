# frozen_string_literal: true

module DocAuth
  module LexisNexis
    class DdpClient
      VALID_REVIEW_STATUSES = %w[pass review reject].freeze

      attr_reader :config

      def initialize(attrs)
        @config = DocAuth::LexisNexis::DdpConfig.new(attrs)
        @config.validate!
      end

      # rubocop:disable Lint/UnusedMethodArgument
      def post_images(
        document_type_requested:,
        passport_requested:,
        liveness_checking_required:,
        front_image:,
        back_image:,
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

      private

      # TODO: check to delete this method
      def build_result_from_response(verification_response)
        result = Proofing::DdpResult.new
        body = verification_response.response_body

        result.response_body = body
        result.transaction_id = body['request_id']
        request_result = body['request_result']
        review_status = body['review_status']

        validate_review_status!(review_status)

        result.review_status = review_status
        result.add_error(:request_result, request_result) unless request_result == 'success'
        result.add_error(:review_status, review_status) unless review_status == 'pass'
        result.account_lex_id = body['account_lex_id']
        result.session_id = body['session_id']

        result.success = !result.errors?
        result.client = 'lexisnexis'

        result
      end

      def validate_review_status!(review_status)
        return if VALID_REVIEW_STATUSES.include?(review_status)

        raise "Unexpected review_status value: #{review_status}"
      end
    end
  end
end
