# frozen_string_literal: true

module Proofing
  module Aamva
    module Response
      class AuthenticationTokenResponse
        attr_reader :auth_token

        def initialize(http_response)
          @http_response = http_response
          handle_http_error
          handle_soap_error
          parse_response
        end

        private

        attr_reader :http_response
        attr_writer :auth_token

        def handle_http_error
          status = http_response.status
          return if status == 200
          raise AuthenticationError, "Unexpected status code in response: #{status}"
        end

        def handle_soap_error
          error_handler = SoapErrorHandler.new(http_response)
          return unless error_handler.error_present?
          raise AuthenticationError, error_handler.error_message
        end

        def handle_missing_token_error(token_node)
          return unless token_node.nil?
          raise AuthenticationError, 'The authentication response is missing a token'
        end

        def parse_response
          document = REXML::Document.new(http_response.body)
          token_node = REXML::XPath.first(document, '//Token')
          handle_missing_token_error(token_node)
          self.auth_token = token_node.text
        end
      end
    end
  end
end
