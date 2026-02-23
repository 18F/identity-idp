# frozen_string_literal: true

module Proofing
  module LexisNexis
    module  Ddp
      class ParsedResponse
        attr_reader :response

        def initialize(response)
          @response = response
        end

        def verification_errors
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

        def transaction_reason_code
          response_body.dig('Status', 'TransactionReasonCode', 'Code')
        end

        # @api private
        def response_body
          @response_body ||= parse_response
        rescue JSON::ParserError
          # IF a JSON parse error occurs the resulting error message will contain the portion of the
          # response body where the error occured. This portion of the response could potentially
          # include sensitive informaiton. This commit scrubs the error message by raising a JSON
          # parse error with a generic message.
          error_message = 'An error occured parsing the response body JSON'
          raise JSON::ParserError, error_message
        end

        def product_list
          @product_list = response_body.fetch('Products', [])
        end

        private

        def parse_response
          case response
          when String
            JSON.parse(response)
          when Hash
            response
          else
            raise ArgumentError, "Response must be a JSON string or Hash, got #{response.class}"
          end
        end

        def verification_error_parser
          @verification_error_parser ||= VerificationErrorParser.new(response_body)
        end
      end
    end
  end
end
