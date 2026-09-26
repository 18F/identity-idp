# frozen_string_literal: true

module Proofing
  module Clear1
    module Requests
      class ResultRequest < Proofing::Clear1::Request
        attr_reader :verification_session_id

        def initialize(verification_session_id:)
          @verification_session_id = verification_session_id
          @state_uuid = state_uuid
        end

        private

        def metric_name
          'clear1_verification_data_request'
        end

        def handle_http_response(response)
          response_body = JSON.parse(response.body, symbolize_names: true)
          Clear1::Response.new(response_body:)
        end

        def endpoint
          [
            IdentityConfig.store.idv_clear1_api_base_url,
            'v1',
            'verification_sessions',
            verification_session_id,
          ].join('/')
        end
      end
    end
  end
end
