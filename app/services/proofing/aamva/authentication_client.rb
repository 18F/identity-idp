module Proofing
  module Aamva
    class AuthenticationClient
      AAMVA_TOKEN_FRESHNESS_SECONDS = 28 * 60

      class << self
        attr_accessor :auth_token
        attr_accessor :auth_token_expiration
      end

      def self.token_mutex
        @token_mutex ||= Mutex.new
      end

      def fetch_token(config)
        AuthenticationClient.token_mutex.synchronize do
          if AuthenticationClient.auth_token.nil? || auth_token_expired?
            send_auth_token_request(config)
          end
          AuthenticationClient.auth_token
        end
      end

      private

      def send_auth_token_request(config)
        sct_request = Request::SecurityTokenRequest.new(config)
        sct_response = sct_request.send
        token_request = Request::AuthenticationTokenRequest.new(
          config: config,
          security_context_token_identifier: sct_response.security_context_token_identifier,
          security_context_token_reference: sct_response.security_context_token_reference,
          client_hmac_secret: sct_request.nonce,
          server_hmac_secret: sct_response.nonce,
        )
        token_response = token_request.send
        AuthenticationClient.auth_token = token_response.auth_token
        AuthenticationClient.auth_token_expiration = Time.zone.now + AAMVA_TOKEN_FRESHNESS_SECONDS
      end

      def auth_token_expired?
        (AuthenticationClient.auth_token_expiration - Time.zone.now).negative?
      end
    end
  end
end
