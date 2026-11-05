# frozen_string_literal: true

module UsersReport
  class ReportConfigResolver
    class ConfigurationError < StandardError; end

    def initialize(issuer)
      @issuer = issuer
    end

    # @raise [ConfigurationError] if the issuer maps to zero or more than one config
    def report_config
      raise ConfigurationError, 'Issuer is blank' if @issuer.blank?

      matches = IdentityConfig.store.sp_proofing_events_by_uuid_report_configs.select do |config|
        Array(config['issuers']).include?(@issuer)
      end

      unless matches.one?
        raise ConfigurationError,
              "Expected exactly one report config for the issuer, found #{matches.length}"
      end

      matches.first
    end

    def agency_abbreviation
      report_config['agency_abbreviation']
    rescue ConfigurationError
      nil
    end
  end
end
