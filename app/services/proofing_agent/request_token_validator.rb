# frozen_string_literal: true

module ProofingAgent
  class RequestTokenValidator < Api::RequestTokenValidator
    private

    def config_data_exists
      return if config_data_exists?

      errors.add(
        :issuer,
        :not_authorized,
        message: 'Issuer is not authorized to use Proofing Agent',
      )
    end

    def config_data
      @config_data ||= IdentityConfig.store.idv_proofing_agent_config.find do |config|
        config['issuer'] == issuer
      end
    end
  end
end
