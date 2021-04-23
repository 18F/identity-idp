module Idv
  module Steps
    class RecoverVerifyStep < VerifyBaseStep
      STEP_INDICATOR_STEP = :verify_info

      def call
        enqueue_job
      end

      private

      def enqueue_job
        return if flow_session[recover_verify_document_capture_session_uuid_key]

        pii_from_doc = flow_session[:pii_from_doc]
        pii_from_doc[:uuid_prefix] = ServiceProvider.from_issuer(sp_session[:issuer]).app_id

        document_capture_session = create_document_capture_session(
          recover_verify_document_capture_session_uuid_key,
        )

        document_capture_session.requested_at = Time.zone.now
        document_capture_session.create_proofing_session

        Idv::Agent.new(pii_from_doc).proof_resolution(
          document_capture_session,
          should_proof_state_id: should_use_aamva?(pii_from_doc),
          trace_id: amzn_trace_id,
        )
      end
    end
  end
end
