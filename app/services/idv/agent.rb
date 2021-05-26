module Idv
  class Agent
    def initialize(applicant)
      @applicant = applicant.symbolize_keys
    end

    def proof_resolution(
      document_capture_session,
      should_proof_state_id:,
      trace_id:,
      document_expired:
    )
      document_capture_session.create_proofing_session

      encrypted_arguments =
        Encryption::Encryptors::SessionEncryptor.new.encrypt({ applicant_pii: @applicant }.to_json)

      ResolutionProofingJob.perform_later(
        encrypted_arguments: encrypted_arguments,
        should_proof_state_id: should_proof_state_id,
        dob_year_only: IdentityConfig.store.proofing_send_partial_dob,
        trace_id: trace_id,
        result_id: document_capture_session.result_id,
        document_expired: document_expired,
      )
    end

    def proof_address(document_capture_session, user_id:, issuer:, trace_id:)
      document_capture_session.create_proofing_session
      encrypted_arguments =
        Encryption::Encryptors::SessionEncryptor.new.encrypt({ applicant_pii: @applicant }.to_json)

      AddressProofingJob.perform_later(
        user_id: user_id,
        issuer: issuer,
        encrypted_arguments: encrypted_arguments,
        result_id: document_capture_session.result_id,
        trace_id: trace_id,
      )
    end

    def proof_document(
      document_capture_session,
      liveness_checking_enabled:,
      trace_id:,
      analytics_data:
    )
      encrypted_arguments =
        Encryption::Encryptors::SessionEncryptor.new.encrypt(
          { document_arguments: @applicant }.to_json,
        )

      DocumentProofingJob.perform_later(
        encrypted_arguments: encrypted_arguments,
        liveness_checking_enabled: liveness_checking_enabled,
        result_id: document_capture_session.result_id,
        trace_id: trace_id,
        analytics_data: analytics_data,
      )
    end
  end
end
