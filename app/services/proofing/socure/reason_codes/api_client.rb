# frozen_string_literal: true

module Proofing
  module Socure
    module ReasonCodes
      class ApiClient
        class ApiClientError < StandardError; end

        def download_reason_codes
          http_response = make_reason_code_http_request
          http_response.body['reasonCodes']
        rescue Faraday::ConnectionFailed,
               Faraday::ServerError,
               Faraday::SSLError,
               Faraday::TimeoutError,
               Faraday::ClientError,
               Faraday::ParsingError => e
          raise ApiClientError, e.message
        end

        private

        def make_reason_code_http_request
          conn = Faraday.new do |f|
            f.request :instrumentation, name: 'request_metric.faraday'
            f.response :raise_error
            f.response :json
            f.options.timeout = IdentityConfig.store.socure_reason_code_timeout_in_seconds
          end

          conn.get(url, { group: true }, headers) do |req|
            req.options.context = { service_name: 'socure_reason_codes' }
          end
        end

        def headers
          {
            'Content-Type' => 'application/json',
            'Authorization' => "SocureApiKey #{IdentityConfig.store.socure_reason_code_api_key}",
          }
        end

        def url
          URI.join(
            IdentityConfig.store.socure_reason_code_base_url,
            '/api/3.0/reasoncodes',
          ).to_s
        end
      end
    end
  end
end
