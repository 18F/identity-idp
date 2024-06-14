# frozen_string_literal: true

module Idv
  module SocureConcern
    def uploaded_documents_decision(socure_document_uuid)
      # return if IdentityConfig.store.socure_verification_level > 1
      return unless document_capture_session

      document_verification_req = DocAuth::Socure::Requests::EmailAuthScore.new(
        modules: ['documentverification'],
        document_uuid: socure_document_uuid,
        customer_user_id: document_capture_session.uuid,
      )

      decision = document_verification_req.fetch
      # log decision here -- analytics not available
      verify_document_data(decision.dig('documentVerification'))
    end

    def verify_document_data(data)
      doc_auth_response = DocAuth::Socure::Responses::Verification.new(data)
      if doc_auth_response.success?
        doc_pii_response = Idv::DocPiiForm.new(
          pii: doc_auth_response.pii_from_doc.to_h,
          attention_with_barcode: doc_auth_response.attention_with_barcode?,
        ).submit
        if doc_pii_response.success?
          document_capture_session.store_result_from_response(doc_auth_response)
          return
        end
      end

      document_capture_session.store_failed_auth_data(
        front_image_fingerprint: nil,
        back_image_fingerprint: nil,
        selfie_image_fingerprint: nil,
        doc_auth_success: doc_auth_response.doc_auth_success?,
        selfie_status: doc_auth_response.selfie_status,
      )
    end
  end
end
