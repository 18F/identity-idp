# frozen_string_literal: true

module DocAuth
  module Socure
    module Requests
      class DocumentRequest < DocAuth::Socure::Request
        attr_reader :document_type, :redirect_url, :language

        def initialize(
          redirect_url:,
          language:,
          document_type: 'license'
        )
          @redirect_url = redirect_url
          @document_type = document_type
          @language = language
        end

        def body
          redirect = {
            method: 'GET',
            url: redirect_url,
          }

          redirect = nil if Rails.env.development?

          {
            config: {
              documentType: document_type,
              redirect: redirect,
              language: lang(language),
            },
          }.to_json
        end

        private

        def lang(language)
          return 'zh-cn' if language == :zh
          language
        end

        def handle_http_response(http_response)
          JSON.parse(http_response.body, symbolize_names: true)
        end

        def handle_connection_error(exception:, status: nil, status_message: nil, reference_id: nil)
          NewRelic::Agent.notice_error(exception)
          {
            success: false,
            errors: { network: true },
            exception: exception,
            extra: {
              vendor: 'Socure',
              vendor_status: status,
              vendor_status_message: status_message,
              reference_id:,
            }.compact,
          }
        end

        def method
          :post
        end

        def endpoint
          if DocAuth::Mock::Socure.instance.enabled?
            return Rails.application.routes.url_helpers.test_mock_socure_api_document_request_url
          end

          IdentityConfig.store.socure_docv_document_request_endpoint
        end

        def metric_name
          'socure_doc_auth_docv'
        end
      end
    end
  end
end
