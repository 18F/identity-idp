# frozen_string_literal: true

module DocAuth
  module Socure
    module Requests
      class DocumentRequest < DocAuth::Socure::Request
        attr_reader :document_type, :redirect_url, :document_capture_session_uuid

        def initialize(
          document_capture_session_uuid:, redirect_url:,
          document_type: 'license'
        )
          @document_capture_session_uuid = document_capture_session_uuid
          @redirect_url = redirect_url
          @document_type = document_type
        end

        private

        def body
          {
            config: {
              documentType: document_type,
              redirect: {
                method: 'GET',
                url: redirect_url,
              },
            },
            customerUserId: document_capture_session_uuid,
            verificationLevel: IdentityConfig.store.socure_verification_level,
          }.to_json
        end

        def handle_http_response(http_response)
          JSON.parse(http_response.body)
        end

        def method
          :post
        end

        def endpoint
          IdentityConfig.store.socure_document_request_endpoint
        end

        def metric_name
          'socure_doc_auth_docv'
        end
      end
    end
  end
end
