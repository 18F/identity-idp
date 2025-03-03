# frozen_string_literal: true

module DocAuth
  module Dos
    module Requests
      class HealthCheckRequest
        UNUSED_RESPONSE_KEYS = %i[
          attention_with_barcode
          doc_type_supported
          selfie_live
          selfie_quality_good
          doc_auth_success
          selfie_status
        ].freeze

        def initialize(endpoint:)
          @endpoint = endpoint
        end

        def fetch(analytics)
          begin
            faraday_response = connection.get
            response = Responses::HealthCheckResponse.new(faraday_response:)
          rescue Faraday::Error => faraday_error
            response = Responses::HealthCheckResponse.new(faraday_response: faraday_error)
          end
        ensure
          analytics.passport_api_health_check(
            **response.to_h
                .except(*UNUSED_RESPONSE_KEYS)
                .merge(response.extra),
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
