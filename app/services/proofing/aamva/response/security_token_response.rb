# frozen_string_literal: true

require 'rexml/document'
require 'rexml/xpath'

module Proofing
  module Aamva
    module Response
      class SecurityTokenResponse
        attr_reader :security_context_token_identifier, :security_context_token_reference

        def initialize(http_response)
          @http_response = http_response
          handle_http_error
          handle_soap_error
          parse_response
        end

        def nonce
          document = REXML::Document.new(http_response.body)
          REXML::XPath.first(
            document,
            '//trust:BinarySecret',
            'trust' => 'http://schemas.xmlsoap.org/ws/2005/02/trust',
          ).text
        end

        private

        attr_reader :http_response
        attr_writer :security_context_token_identifier, :security_context_token_reference

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
          raise AuthenticationError,
                'The authentication response is missing a security context token'
        end

        def parse_response
          handle_missing_token_error(security_context_token_node)
          token_id_node = REXML::XPath.first(
            security_context_token_node,
            '//sc:Identifier',
            'sc' => 'http://schemas.xmlsoap.org/ws/2005/02/sc',
          )
          self.security_context_token_identifier = token_id_node.text
          self.security_context_token_reference = security_context_token_node.attributes['Id']
        end

        def security_context_token_node
          @security_context_token_node ||= REXML::XPath.first(
            REXML::Document.new(http_response.body),
            '//tr:RequestSecurityTokenResponse/tr:RequestedSecurityToken/sc:SecurityContextToken',
            'tr' => 'http://schemas.xmlsoap.org/ws/2005/02/trust',
            'sc' => 'http://schemas.xmlsoap.org/ws/2005/02/sc',
          )
        end
      end
    end
  end
end
