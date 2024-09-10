# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      class FetchResultsRequest < Request
        def initialize(config:, reference_id:)
          # ToDo: extract commonality to base class
          @api_key = config[:api_key]
          @timeout = config[:timeout]
          @url = URI.join(
            config[:base_url],
            '/api/3.0/transaction',
            "?referenceId=#{reference_id}",
          ).to_s
        end

        def send_request
          conn = Faraday.new do |f|
            f.request :instrumentation, name: 'request_metric.faraday'
            f.response :raise_error
            f.response :json
            f.options.timeout = timeout
            f.options.read_timeout = timeout
            f.options.open_timeout = timeout
            f.options.write_timeout = timeout
          end

          raw_response = conn.post(url, body, headers) do |req|
            req.options.context = { service_name: SERVICE_NAME }
          end

          Response.new(raw_response)
        rescue Faraday::BadRequestError,
               Faraday::ConnectionFailed,
               Faraday::ServerError,
               Faraday::SSLError,
               Faraday::TimeoutError,
               Faraday::UnauthorizedError => e

          if timeout_error?(e)
            raise ::Proofing::TimeoutError,
                  'Timed out waiting for verification response'
          end

          raise RequestError, e
        end

        def body
          JSON.generate({})
        end

        def headers
          {
            'Content-Type' => 'application/json',
            'Authorization' => "SocureApiKey #{api_key}",
          }
        end

        private

        attr_reader :api_key, :reference_id, :timeout, :url
      end
    end
  end
end
