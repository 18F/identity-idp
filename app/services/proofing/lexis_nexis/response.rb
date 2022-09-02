module Proofing
  module LexisNexis
    class Response
      class UnexpectedHTTPStatusCodeError < StandardError; end

      attr_reader :response

      def initialize(response)
        @response = response
        handle_unexpected_http_status_code_error
      end

      def verification_errors
        return {} if verification_status == 'passed'

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
        @verification_error_parser ||= VerificationErrorParser.new(response_body)
      end

      def handle_unexpected_http_status_code_error
        return if response.success?

        message = "Unexpected status code '#{response.status}': #{response.body}"
        raise UnexpectedHTTPStatusCodeError, message
      end
    end
  end
end
