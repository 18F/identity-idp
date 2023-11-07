module Proofing
  module LexisNexis
    class RequestSigner
      attr_accessor :config, :message_body, :path, :host

      # @param [#base_url,#hmac_key_id,#hmac_secret_key] config
      def initialize(config:, message_body:, path:)
        @config = config
        @message_body = message_body
        @path = path
        @host = config.base_url.gsub('https://', '')
      end

      # HMAC auth header from RDP_REST_V3_DecisioningGuide_March22.pdf, page 21
      def hmac_authorization(timestamp: Time.zone.now.strftime('%s%L'), nonce: SecureRandom.uuid)
        hmac = OpenSSL::HMAC.base64digest('SHA256', config.hmac_secret_key, message_body)
        signature = build_signature(
          timestamp:,
          nonce:,
          body_hash: hmac,
        )
        %W[
          HMAC-SHA256
          keyid=#{config.hmac_key_id},
          ts=#{timestamp},
          nonce=#{nonce},
          bodyHash=#{hmac},
          signature=#{signature}
        ].join(' ')
      end

      private

      # Signature definition from RDP_REST_V3_DecisioningGuide_March22.pdf, page 20
      def build_signature(timestamp:, nonce:, body_hash:)
        message = [
          timestamp,
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
