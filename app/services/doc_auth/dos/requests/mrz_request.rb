# frozen_string_literal: true

module DocAuth
  module Dos
    module Requests
      class MrzRequest < DocAuth::Dos::Request
        def initialize(mrz:)
          @mrz = mrz
        end

        private

        attr_reader :correlation_id, :mrz

        def category
          :book # for now, the only supported option
        end

        def http_method
          :post
        end

        def metric_name
          'dos_doc_auth_passport_mrz'
        end

        def handle_http_response(response)
          result = JSON.parse(response.body, symbolize_names: true)
          case result[:response]
          when 'YES'
            DocAuth::Response.new(success: true, errors: {}, exception: nil)
          when 'NO'
            DocAuth::Response.new(success: false, errors: {}, exception: nil)
          else
            DocAuth::Response.new(
              success: false,
              errors: { message: "Unexpected response: #{result[:response]}" },
              exception: nil,
            )
          end
        end

        def endpoint
          IdentityConfig.store.dos_passport_mrz_endpoint
        end

        def request_headers
          correlation_id = SecureRandom.uuid
          {
            'Content-Type': 'application/json',
            'X-Correlation-ID': correlation_id,
            client_id: IdentityConfig.store.dos_passport_client_id,
            client_secret: IdentityConfig.store.dos_passport_client_secret,
          }
        end

        def body
          {
            mrz:,
            category:,
          }.to_json
        end
      end
    end
  end
end
