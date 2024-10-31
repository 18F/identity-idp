# frozen_string_literal: true

module DocAuth
  module Socure
    module Requests
      class DocumentRequest < DocAuth::Socure::Request
        attr_reader :document_type, :redirect_url, :document_capture_session_uuid, :language

        def initialize(
          document_capture_session_uuid:,
          redirect_url:,
          language:,
          document_type: 'license'
        )
          @document_capture_session_uuid = document_capture_session_uuid
          @redirect_url = redirect_url
          @document_type = document_type
          @language = language
        end

        private

        def lang(language)
          return 'zh-cn' if language == :zh
          language
        end

        def body
          redirect = {
            method: 'POST',
            url: redirect_url,
          }

          redirect = nil if Rails.env.development?

          {
            config: {
              documentType: document_type,
              redirect: redirect,
              language: lang(language),
            },
            customerUserId: document_capture_session_uuid,
          }.to_json
        end

        def handle_http_response(http_response)
          JSON.parse(http_response.body, symbolize_names: true)
        end

        def handle_invalid_response(http_response)
          message = [
            self.class.name,
            'Unexpected HTTP response',
            http_response.status,
          ].join(' ')
          exception = DocAuth::RequestError.new(message, http_response.status)

          response_body = begin
            http_response.body.present? ? JSON.parse(http_response.body) : {}
          rescue JSON::JSONError
            {}
          end

          handle_connection_error(
            exception: exception,
            status_code: response_body.dig('status', 'code'),
            status_message: response_body.dig('status', 'message'),
          )
        end

        def handle_connection_error(exception:, status_code: nil, status_message: nil)
          NewRelic::Agent.notice_error(exception)
          {
            success: false,
            errors: { network: true },
            exception: exception,
            extra: {
              vendor: 'Socure',
              selfie_live: false,
              selfie_quality_good: false,
              vendor_status_code: status_code,
              vendor_status_message: status_message,
            }.compact,
          }
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
