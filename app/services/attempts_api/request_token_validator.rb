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

    def config_data
      @config_data ||= IdentityConfig.store.allowed_attempts_providers.find do |config|
        config['issuer'] == issuer
      end
    end
  end
end
