# frozen_string_literal: true

module DocAuth
  module Dos
    module Requests
      class MrzRequest < DocAuth::Dos::Request
        def initialize(mrz:)
          @mrz = mrz
        end

        private

        attr_reader :mrz

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
          extra = {
            vendor: 'DoS',
            correlation_id_sent: correlation_id,
            correlation_id_received: response.headers['X-Correlation-ID'],
            response: result[:response],
          }.compact
          case result[:response]
          when 'YES'
            DocAuth::Response.new(success: true, errors: {}, exception: nil, extra:)
          when 'NO'
            DocAuth::Response.new(
              success: false,
              errors: { passport: 'invalid MRZ' },
              exception: nil,
              extra:,
            )
          else
            DocAuth::Response.new(
              success: false,
              errors: { message: "Unexpected response: #{result[:response]}" },
              exception: nil,
              extra:,
            )
          end
        end

        def endpoint
          IdentityConfig.store.dos_passport_mrz_endpoint
        end

        def request_headers
          @correlation_id = SecureRandom.uuid
          {
            'Content-Type': 'application/json',
            'X-Correlation-ID': correlation_id,
            'Client-Id': IdentityConfig.store.dos_passport_client_id,
            'Client-Secret': IdentityConfig.store.dos_passport_client_secret,
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
