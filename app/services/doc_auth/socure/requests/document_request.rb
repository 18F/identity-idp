# frozen_string_literal: true

module DocAuth
  module Socure
    module Requests
      class DocumentRequest < DocAuth::Socure::Request
        attr_reader :customer_user_id, :document_type, :redirect_url, :language, :liveness_checking_required

        def initialize(
          customer_user_id:,
          redirect_url:,
          language:,
          document_type: 'license',
          liveness_checking_required: false
        )
          @customer_user_id = customer_user_id
          @redirect_url = redirect_url
          @document_type = document_type
          @language = language
          @liveness_checking_required = liveness_checking_required
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
              useCaseKey: use_case_key,
            },
            customerUserId: customer_user_id,
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

        def use_case_key
          if liveness_checking_required
            IdentityConfig.store.idv_socure_docv_flow_id_w_selfie
          else
            IdentityConfig.store.idv_socure_docv_flow_id_only
          end
        end
      end
    end
  end
end
