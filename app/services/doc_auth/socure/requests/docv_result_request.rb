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
            docvTransactionToken: document_capture_session.socure_docv_token,
            customerUserId: document_capture_session_uuid,
          }.to_json
        end

        def handle_http_response(http_response)
          socure_response = DocAuth::Socure::Responses::DocvResultResponse.new(
            http_response: http_response,
            biometric_comparison_required: biometric_comparison_required,
          )
          response = Idv::DocPiiForm.new(
            pii: socure_response.pii_from_doc.to_h,
            attention_with_barcode: false, # n/a
          ).submit

          if response.success?
            document_capture_session.store_result_from_response(socure_response)
          else # rubocop:disable Style/EmptyElse
            # log errors
          end
        end

        def document_capture_session
          @document_capture_session ||=
            DocumentCaptureSession.find_by!(uuid: document_capture_session_uuid)
        end

        def method
          :post
        end

        def endpoint
          IdentityConfig.store.socure_idplus_endpoint
        end

        def metric_name
          'socure_doc_auth_docv'
        end
      end
    end
  end
end
