# frozen_string_literal: true

module Proofing
  module Clear
    module Requests
      class SessionRequest < Proofing::Clear::Request
        private

        def http_method
          :post
        end

        def metric_name
          'clear_session_request'
        end

        def handle_http_response(response)
          JSON.parse(response.body, symbolize_names: true)
          # puts result.inspect
          # extra = {}
          #   vendor_name: 'dos:passport',
          #   correlation_id_sent: correlation_id,
          #   correlation_id_received: response.headers['X-Correlation-ID'],
          #   response: result[:response],
          # }.compact
          # case result[:response]
          # when 'YES'
          #   DocAuth::Response.new(success: true, errors: {}, exception: nil, extra:)
          # when 'NO'
          #   DocAuth::Response.new(
          #     success: false,
          #     errors: { passport: I18n.t('doc_auth.errors.general.fallback_field_level') },
          #     exception: nil,
          #     extra:,
          #   )
          # else
          #   DocAuth::Response.new(
          #     success: false,
          #     errors: { message: "Unexpected response: #{result[:response]}" },
          #     exception: nil,
          #     extra:,
          #   )
          # end
        end

        def endpoint
          [
            IdentityConfig.store.idv_clear_api_base_url,
            'v1',
            'verification_sessions',
          ].join('/')
        end

        def request_headers
          {
            'Content-Type': 'application/json',
            Authorization: "Bearer #{IdentityConfig.store.idv_clear_api_key}",
          }
        end

        def body
          {
            project_id: IdentityConfig.store.idv_clear_project_id,
            redirect_url: '',
          }.to_json
        end
      end
    end
  end
end
