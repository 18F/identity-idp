# frozen_string_literal: true

module ProofingAgent
  module Config
    private

    def issuer_config
      @issuer_config ||= config&.find do |config_data|
        config_data['issuer'] == service_provider_issuer
      end
    end

    def config
      @config ||= IdentityConfig.store.idv_proofing_agent_config
    end

    def webhook_url
      issuer_config&.dig('webhook', 'url')
    end

    def webhook_secret
      issuer_config&.dig('webhook', 'secret')
    end

    def webhook_custom_headers
      issuer_config&.dig('webhook', 'headers') || {}
    end
  end
end
