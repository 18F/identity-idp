# frozen_string_literal: true

module DocAuth
  module Dos
    module Requests
      class CompositeHealthCheckRequest
        def fetch(analytics)
          begin
            faraday_response = connection.get
            response = Responses::GeneralHealthCheckSuccess.new(faraday_response)
          rescue Faraday::Error => faraday_error
            response = Responses::GeneralHealthCheckFailure.new(faraday_error)
          end
        ensure
          analytics.passport_api_health_check(
            success: response.success?,
            **response.extra,
          )
        end

        private

        def connection
          @connection ||= Faraday::Connection.new(
            url: IdentityConfig.store.dos_passport_composite_healthcheck_endpoint,
          ) do |builder|
            builder.response :raise_error
          end
        end
      end
    end
  end
end
