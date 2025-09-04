# frozen_string_literal: true

module DocAuth
  module Socure
    module Requests
      class DocumentRequest < DocAuth::Socure::Request
        attr_reader :customer_user_id, :redirect_url, :language,
                    :liveness_checking_required, :passport_requested

        PASSPORT_DOCUMENT_TYPE = 'passport'
        DRIVERS_LICENSE_DOCUMENT_TYPE = 'license'

        def initialize(
          customer_user_id:,
          redirect_url:,
          language:,
          liveness_checking_required: false,
          passport_requested: false
        )
          @customer_user_id = customer_user_id
          @redirect_url = redirect_url
          @language = language
          @liveness_checking_required = liveness_checking_required
          @passport_requested = passport_requested
        end

        def body
          redirect = {
            method: 'GET',
            url: redirect_url,
          }

          redirect = nil if Rails.env.development?

          {
            config: {
              documentType: document_type_requested,
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

        def method
          :post
        end

        def endpoint
          if DocAuth::Mock::Socure.instance.enabled?
            return DocAuth::Mock::Socure.instance.document_request_endpoint
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

        def document_type_requested
          passport_requested ? PASSPORT_DOCUMENT_TYPE : DRIVERS_LICENSE_DOCUMENT_TYPE
        end
      end
    end
  end
end
