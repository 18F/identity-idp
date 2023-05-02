module Proofing
  module LexisNexis
    class RequestSigner
      attr_accessor :config, :message_body, :path

      # @param config must respond to base_url, hmac_key_id, and hmac_secret_key
      def initialize(config:, message_body:, path:)
        @config = config
        @message_body = message_body
        @path = path
      end

      # Example HMAC auth header from RDP_REST_V3_DecisioningGuide_March22.pdf, page 21
      def hmac_authorization(ts: Time.zone.now.strftime('%s%L'), nonce: SecureRandom.uuid)
        hmac = OpenSSL::HMAC.base64digest('SHA256', config.hmac_secret_key, message_body)
        host = config.base_url.gsub('https://', '')
        signature = build_signature(ts, nonce, host, path, hmac)
        %W[
          HMAC-SHA256
          keyid=#{config.hmac_key_id},
          ts=#{ts},
          nonce=#{nonce},
          bodyHash=#{hmac},
          signature=#{signature}
        ].join(' ')
      end

      private

      # Signature definition from RDP_REST_V3_DecisioningGuide_March22.pdf, page 20
      def build_signature(ts, nonce, host, path, body_hash)
        message = [
          ts,
          nonce,
          host,
          path,
          body_hash,
        ].join("\n")
        OpenSSL::HMAC.base64digest('SHA256', config.hmac_secret_key, message)
      end
    end
  end
end
