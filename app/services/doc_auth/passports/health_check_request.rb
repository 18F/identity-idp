# frozen_string_literal: true

module DocAuth
  module Passports
    class HealthCheckRequest
      def initialize(analytics:)
        @analytics = analytics
      end

      def fetch
        begin
          faraday_response = connection.get
          response = HealthCheckResponseOk.new(faraday_response)
        rescue Faraday::Error => faraday_error
          response = HealthCheckResponseFailure.new(faraday_error)
        end
      ensure
        analytics.passport_api_health_check(
          success: response.success?,
          **response.extra,
        )
      end

      private

      attr_reader :analytics

      def connection
        @connection ||= Faraday::Connection.new(
          url: IdentityConfig.store.passports_api_health_check_endpoint,
        ) do |builder|
          builder.response :raise_error
        end
      end
    end
  end
end
