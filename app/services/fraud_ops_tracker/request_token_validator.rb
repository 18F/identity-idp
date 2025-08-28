# frozen_string_literal: true

module FraudOpsTracker
  class RequestTokenValidator < AttemptsApi::RequestTokenValidator
    private

    def config_data
      @config_data ||= IdentityConfig.store.fraudops_config
    end

    def config_data_exists
      return if config_data_exists?
      errors.add(
        'fraudops',
        :not_authorized,
        message: 'fraudops not configured',
      )
    end

    def service_provider_exists
      return if FeatureManagement.fraudops_enabled?

      errors.add(
        'fraudops',
        :not_authorized,
        message: 'fraudops Not enabled',
      )
    end
  end
end
