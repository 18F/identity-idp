module Proofing
  module LexisNexis
    class Response
      class TrackedError < StandardError
        attr_reader :conversation_id, :reference

        def initialize(message = '', conversation_id:, reference:)
          super(message)

          @conversation_id = conversation_id
          @reference = reference
        end
      end

      class UnexpectedHTTPStatusCodeError < StandardError; end

      class UnexpectedVerificationStatusCodeError < TrackedError; end

      class VerificationTransactionError < TrackedError; end

      attr_reader :response

      # @param [Boolean] dob_year_only
      # @see VerificationErrorParser#initialize
      def initialize(response, dob_year_only: false)
        @response = response
        @dob_year_only = dob_year_only
        handle_unexpected_http_status_code_error
        handle_unexpected_verification_status_error
        handle_verification_transaction_error
      end

      def dob_year_only?
        @dob_year_only
      end

      def verification_errors
        return {} unless verification_status == 'failed'

        verification_error_parser.parsed_errors
      end

      def verification_status
        verification_error_parser.verification_status
      end

      def conversation_id
        @conversation_id ||= response_body.dig('Status', 'ConversationId')
      end

      def reference
        @reference ||= response_body.dig('Status', 'Reference')
      end

      # @api private
      def response_body
        @response_body ||= JSON.parse(response.body)
      end

      private

      def verification_error_parser
        @verification_error_parser ||= VerificationErrorParser.new(
          response_body,
          dob_year_only: dob_year_only?,
        )
      end

      def handle_unexpected_http_status_code_error
        return if response.success?

        message = "Unexpected status code '#{response.status}': #{response.body}"
        raise UnexpectedHTTPStatusCodeError, message
      end

      def handle_unexpected_verification_status_error
        return if %w[passed failed error].include?(verification_status)

        message = "Invalid status in response body: '#{verification_status}'"
        raise UnexpectedVerificationStatusCodeError.new(
          message,
          conversation_id: conversation_id,
          reference: reference,
        )
      end

      def handle_verification_transaction_error
        return unless verification_status == 'error'

        error_code = response_body.dig('Status', 'TransactionReasonCode', 'Code')
        error_information = response_body.fetch('Information', {}).to_json
        tracking_ids = "(LN ConversationId: #{conversation_id}; Reference: #{reference}) "

        message = "#{tracking_ids} Response error with code '#{error_code}': #{error_information}"
        raise VerificationTransactionError.new(
          message,
          conversation_id: conversation_id,
          reference: reference,
        )
      end
    end
  end
end
