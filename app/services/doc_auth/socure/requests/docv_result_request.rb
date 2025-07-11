# frozen_string_literal: true

module DocAuth
  module Socure
    module Requests
      class DocvResultRequest < DocAuth::Socure::Request
        attr_reader :document_capture_session_uuid

        def initialize(
          customer_user_id:,
          document_capture_session_uuid:,
          user_email:,
          docv_transaction_token_override: nil
        )
          @customer_user_id = customer_user_id
          @user_email = user_email
          @document_capture_session_uuid = document_capture_session_uuid
          @docv_transaction_token_override = docv_transaction_token_override
        end

        private

        attr_reader :customer_user_id, :docv_transaction_token_override, :user_email

        def body
          {
            modules: ['documentverification'],
            docvTransactionToken: docv_transaction_token,
            customerUserId: customer_user_id,
            email: user_email,
          }.to_json
        end

        def handle_http_response(http_response)
          DocAuth::Socure::Responses::DocvResultResponse.new(
            http_response: http_response,
            passport_requested: document_capture_session&.passport_requested?,
          )
        end

        def handle_connection_error(exception:, status: nil, status_message: nil, reference_id: nil)
          DocAuth::Response.new(**super)
        end

        def document_capture_session
          @document_capture_session ||=
            DocumentCaptureSession.find_by!(uuid: document_capture_session_uuid)
        end

        def method
          :post
        end

        def endpoint
          if DocAuth::Mock::Socure.instance.enabled?
            return DocAuth::Mock::Socure.instance.results_endpoint
          end

          @endpoint ||= URI.join(
            IdentityConfig.store.socure_idplus_base_url,
            '/api/3.0/EmailAuthScore',
          ).to_s
        end

        def metric_name
          'socure_id_plus_document_verification'
        end

        def docv_transaction_token
          if IdentityConfig.store.socure_docv_verification_data_test_mode &&
             IdentityConfig.store.socure_docv_verification_data_test_mode_tokens
                 .include?(docv_transaction_token_override)
            return docv_transaction_token_override
          end

          document_capture_session.socure_docv_transaction_token
        end
      end
    end
  end
end
