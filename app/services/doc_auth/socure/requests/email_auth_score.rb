# frozen_string_literal: true

module DocAuth
  module Socure
    module Requests
      class EmailAuthScore < DocAuth::Socure::Request
        attr_reader :modules, :document_uuid, :customer_user_id

        def initialize(
          modules:,
          document_uuid: nil,
          customer_user_id: nil
        )
          @modules = modules
          @document_uuid = document_uuid
          @customer_user_id = customer_user_id
        end

        private

        def body
          {
            modules: modules,
            customerUserId: customer_user_id,
            documentUuid: document_uuid,
          }.to_json
        end

        def handle_http_response(http_response)
          JSON.parse(http_response.body)
        end

        def method
          :post
        end

        def endpoint
          IdentityConfig.store.socure_id_plus_endpoint
        end

        def metric_name
          'socure_doc_auth_docv'
        end
      end
    end
  end
end
