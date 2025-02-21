# frozen_string_literal: true

module DocAuth
  module Dos
    module Requests
      class HealthCheckRequest
        def initialize(endpoint:)
          @endpoint = endpoint
        end

        def fetch(analytics)
          begin
            faraday_response = connection.get
            response = Responses::HealthCheckSuccess.new(faraday_response)
          rescue Faraday::Error => faraday_error
            response = Responses::HealthCheckFailure.new(faraday_error)
          rescue StandardError => e
            response = Responses::HealthCheckFailure.new
            raise e
          end
        ensure
          analytics.passport_api_health_check(
            success: response.success?,
            **response&.extra,
          )
        end

        private

        attr_reader :endpoint

        def connection
          @connection ||= Faraday::Connection.new(url: endpoint) do |builder|
            builder.response :raise_error
          end
        end
      end
    end
  end
end
