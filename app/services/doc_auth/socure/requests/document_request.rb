# frozen_string_literal: true

module DocAuth
  module Socure
    module Requests
      class DocumentRequest < DocAuth::Socure::Request
        attr_reader :verification_level, :document_type

        def initialize(verification_level: '2', document_type: 'license')
          @verification_level = verification_level
          @document_type = document_type
        end

        private

        def body
          {
            config: {
              documentType: document_type,
            },
            verificationLevel: verification_level,
          }.to_json
        end

        def handle_http_response(http_response)
          JSON.parse(http_response.body)
        end

        def method
          :post
        end

        def endpoint
          IdentityConfig.store.socure_document_endpoint
        end

        def metric_name
          'socure_doc_auth_docv'
        end
      end
    end
  end
end
