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

    def config
      IdentityConfig.store.idv_proofing_agent_config
    end
  end
end
