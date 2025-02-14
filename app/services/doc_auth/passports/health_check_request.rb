# frozen_string_literal: true

module DocAuth
  module Passports
    class HealthCheckRequest
      def initialize(analytics:)
        @analytics = analytics
      end

      def fetch
        response = Faraday.get(IdentityConfig.store.passports_api_health_check_endpoint)

        analytics.passport_api_health_check

        HealthCheckResponse.new(response)
      end

      private

      attr_reader :analytics
    end
  end
end
