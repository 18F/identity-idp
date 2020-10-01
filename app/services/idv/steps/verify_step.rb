module Idv
  module Steps
    class VerifyStep < VerifyBaseStep
      def call
        enqueue_job
      end

      private

      def enqueue_job
        pii_from_doc = flow_session[:pii_from_doc]

        document_capture_session = DocumentCaptureSession.create(user_id: user_id,
                                                                 requested_at: Time.zone.now)
        document_capture_session.store_proofing_pii_from_doc(pii_from_doc)

        flow_session[:idv_verify_step_document_capture_session_uuid] = document_capture_session.uuid

        VendorProofJob.perform_resolution_proof(document_capture_session.uuid,
                                                should_use_aamva?(pii_from_doc))
      end
    end
  end
end
