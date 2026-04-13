# frozen_string_literal: true

module AttemptsApi
  class RequestTokenValidator < Api::RequestTokenValidator
    private

    def config_data_exists
      return if config_data_exists?

      errors.add(
        :issuer,
        :not_authorized,
        message: 'Issuer is not authorized to use Attempts API',
      )
    end

    def config
      IdentityConfig.store.allowed_attempts_providers
    end
  end
end
