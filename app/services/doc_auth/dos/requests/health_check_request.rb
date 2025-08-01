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

        def fetch(analytics, step)
          begin
            faraday_response = connection.get do |req|
              req.options.context = { service_name: metric_name }
            end
            response = Responses::HealthCheckResponse.new(faraday_response:)
          rescue Faraday::Error => faraday_error
            response = Responses::HealthCheckResponse.new(faraday_response: faraday_error)
          end
        ensure
          analytics.passport_api_health_check(
            **response.to_h
                .except(*UNUSED_RESPONSE_KEYS)
                .merge(response.extra)
                .merge({
                  step:,
                }),
          )
        end

        private

        attr_reader :endpoint

        def connection
          retry_options = {
            max: IdentityConfig.store.dos_passport_healthcheck_maxretry,
            interval: 0.05,
            interval_randomness: 0.5,
            exceptions: [
              Errno::ETIMEDOUT, Timeout::Error, Faraday::TimeoutError, Faraday::ConnectionFailed
            ],
          }

          @connection ||= Faraday::Connection.new(url: endpoint) do |conn|
            conn.request :instrumentation, name: 'request_metric.faraday'
            conn.adapter :net_http
            conn.options.timeout = IdentityConfig.store.dos_passport_healthcheck_timeout_seconds
            conn.request :retry, retry_options

            # raises errors on 4XX or 5XX responses
            conn.response :raise_error
          end
        end

        def metric_name
          'dos_doc_auth_passport_healtcheck'
        end
      end
    end
  end
end
