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
          response_body = JSON.parse(response.body, symbolize_names: true)

          FormResponse.new(
            success: true,
            extra: response_body.slice(
              :id, :object_name, :projet_id, :redirect_url, :expires_at, :created_at, :status, :token, 
            ),
          )
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          FormResponse.new(
            success: false,
            extra: { exception: e.inspect },
          )
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
