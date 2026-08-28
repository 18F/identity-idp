# frozen_string_literal: true

module DocAuth
  module Socure
    module Requests
      class DocumentRequest < DocAuth::Socure::Request
        attr_reader :customer_user_id, :redirect_url, :language, :error_redirect_url,
                    :liveness_checking_required, :document_capture_session

        PASSPORT_DOCUMENT_TYPE = 'passport'
        DRIVERS_LICENSE_DOCUMENT_TYPE = 'license'
        MDL_DOCUMENT_TYPE = 'digital_id'

        def initialize(
          customer_user_id:,
          redirect_url:,
          language:,
          document_capture_session:,
          liveness_checking_required: false,
          error_redirect_url: nil
        )
          @customer_user_id = customer_user_id
          @redirect_url = redirect_url
          @language = language
          @liveness_checking_required = liveness_checking_required
          @document_capture_session = document_capture_session
          @error_redirect_url = error_redirect_url
        end

        def body
          redirect = {
            method: 'GET',
            url: redirect_url,
          }

          error_redirect = {
            method: 'GET',
            url: error_redirect_url,
          }

          if Rails.env.development?
            redirect = nil
            error_redirect = nil
          elsif document_type != MDL_DOCUMENT_TYPE
            error_redirect = nil
          end

          {
            config: {
              documentType: document_type,
              redirect:,
              errorRedirect: error_redirect,
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
          if document_capture_session.mdl_requested?
            IdentityConfig.store.idv_socure_docv_flow_id_only
          elsif liveness_checking_required
            IdentityConfig.store.idv_socure_docv_flow_id_w_selfie
          else
            IdentityConfig.store.idv_socure_docv_flow_id_only
          end
        end

        def document_type
          return PASSPORT_DOCUMENT_TYPE if document_capture_session.passport_book_requested?
          return MDL_DOCUMENT_TYPE if document_capture_session.mdl_requested?

          DRIVERS_LICENSE_DOCUMENT_TYPE
        end
      end
    end
  end
end
