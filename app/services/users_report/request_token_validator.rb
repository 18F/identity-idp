# frozen_string_literal: true

module UsersReport
  class RequestTokenValidator < Api::RequestTokenValidator
    private

    def config_data_exists
      return if config_data_exists?

      errors.add(
        :issuer,
        :not_authorized,
        message: 'Issuer is not authorized to use Users Report API',
      )
    end

    def config
      IdentityConfig.store.users_report_api_config
    end

    def config_data
      return nil if agency_abbreviation.nil?

      @config_data ||= config.find do |report_api_config|
        report_api_config['agency_abbreviation'] == agency_abbreviation
      end
    end

    def agency_abbreviation
      @agency_abbreviation ||= ReportConfigResolver.new(issuer).agency_abbreviation
    end
  end
end
