module Idv
  module Steps
    module Cac
      class VerifyStep < DocAuthBaseStep
        def call
          enqueue_job
        end

        private

        def enqueue_job
          pii_from_doc = flow_session[:pii_from_doc]

          document_capture_session = create_document_capture_session(
            cac_verify_document_capture_session_uuid_key,
          )

          document_capture_session.requested_at = Time.zone.now
          document_capture_session.store_proofing_pii_from_doc(pii_from_doc)

          VendorProofJob.perform_resolution_proof(document_capture_session.uuid, false)
        end
      end
    end
  end
end
