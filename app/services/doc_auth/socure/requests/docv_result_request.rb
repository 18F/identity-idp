# frozen_string_literal: true

module DocAuth
  module Socure
    module Requests
      class DocvResultRequest < DocAuth::Socure::Request
        attr_reader :document_capture_session_uuid, :biometric_comparison_required

        def initialize(document_capture_session_uuid:, biometric_comparison_required: false)
          @document_capture_session_uuid = document_capture_session_uuid
          @biometric_comparison_required = biometric_comparison_required
        end

        private

        def body
          {
            modules: ['documentverification'],
            docvTransactionToken: document_capture_session.socure_docv_transaction_token,
          }.to_json
        end

        def handle_http_response(http_response)
          DocAuth::Socure::Responses::DocvResultResponse.new(
            http_response: http_response,
            biometric_comparison_required: biometric_comparison_required,
          )
        end

        def document_capture_session
          @document_capture_session ||=
            DocumentCaptureSession.find_by!(uuid: document_capture_session_uuid)
        end

        def method
          :post
        end

        def endpoint
          @endpoint ||= URI.join(
            IdentityConfig.store.socure_idplus_base_url,
            '/api/3.0/EmailAuthScore',
          ).to_s
        end

        def metric_name
          'socure_doc_auth_docv'
        end
      end
    end
  end
end
