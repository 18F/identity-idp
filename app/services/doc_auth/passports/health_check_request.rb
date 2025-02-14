# frozen_string_literal: true

module DocAuth
  module Passports
    class HealthCheckRequest
      def initialize(analytics:)
        @analytics = analytics
      end

      def fetch
        response =
          begin
            faraday_response = Faraday.get(IdentityConfig.store.passports_api_health_check_endpoint)
            HealthCheckResponse.new(faraday_response)
          rescue Faraday::Error => faraday_error
            HealthCheckResponse.new(faraday_error)
          end
      ensure
        analytics.passport_api_health_check(
          success: response.success?,
          **response.extra,
        )
      end

      private

      attr_reader :analytics
    end
  end
end
