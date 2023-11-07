module Proofing
  module Aamva
    class AuthenticationClient
      AAMVA_TOKEN_FRESHNESS_SECONDS = 28 * 60
      AUTH_TOKEN_CACHE_KEY = 'aamva_api_auth_token'

      def self.auth_token(config)
        Rails.cache.fetch(
          AUTH_TOKEN_CACHE_KEY,
          skip_nil: true,
          expires_in: AAMVA_TOKEN_FRESHNESS_SECONDS,
        ) do
          send_auth_token_request(config)
        end
      end

      private_class_method
      def self.send_auth_token_request(config)
        sct_request = Request::SecurityTokenRequest.new(config)
        sct_response = sct_request.send
        token_request = Request::AuthenticationTokenRequest.new(
          config:,
          security_context_token_identifier: sct_response.security_context_token_identifier,
          security_context_token_reference: sct_response.security_context_token_reference,
          client_hmac_secret: sct_request.nonce,
          server_hmac_secret: sct_response.nonce,
        )
        token_response = token_request.send
        token_response.auth_token
      end
    end
  end
end
