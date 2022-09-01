module Proofing
  module LexisNexis
    class Response
      class UnexpectedHTTPStatusCodeError < StandardError; end

      attr_reader :response_body

      def initialize(response_body)
        @response_body = JSON.parse(response_body)
      end

      def verification_errors
        return {} if verification_status == 'passed'

        verification_error_parser.parsed_errors
      end

      def verification_status
        @verification_status ||= response_body.dig('Status', 'TransactionStatus')
      end

      def conversation_id
        @conversation_id ||= response_body.dig('Status', 'ConversationId')
      end

      def reference
        @reference ||= response_body.dig('Status', 'Reference')
      end

      private

      def verification_error_parser
        @verification_error_parser ||= VerificationErrorParser.new(response_body)
      end
    end
  end
end
