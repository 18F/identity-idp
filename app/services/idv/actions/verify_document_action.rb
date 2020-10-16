module Idv
  module Actions
    class VerifyDocumentAction < Idv::Steps::DocAuthBaseStep
      def call
        enqueue_job
      end

      def enqueue_job
        document_capture_session = create_document_capture_session(
          verify_document_capture_session_uuid_key,
        )
        document_capture_session.requested_at = Time.zone.now
        document_capture_session.store_proofing_pii_from_doc({})

        VendorDocumentVerificationJob.perform(
          _document_capture_session_uuid: params[:document_capture_session_uuid],
          _encryption_key: params[:encryption_key],
          _front_image_url: params[:front_image_url],
          _back_image_url: params[:back_image_url],
          _selfie_image_url: params[:selfie_image_url],
          _liveness_checking_enabled: params[:liveness_checking_enabled],
        )
      end
    end
  end
end
