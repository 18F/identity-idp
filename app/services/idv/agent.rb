module Idv
  class Agent
    def initialize(applicant)
      @applicant = applicant.symbolize_keys
    end

    def proof_resolution(
      document_capture_session,
      should_proof_state_id:,
      trace_id:,
      user_id:,
      threatmetrix_session_id:,
      request_ip:,
      double_address_verification: false
    )
      document_capture_session.create_proofing_session

      encrypted_arguments = Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
        { applicant_pii: @applicant }.to_json,
      )

      job_arguments = {
        encrypted_arguments: encrypted_arguments,
        should_proof_state_id: should_proof_state_id,
        trace_id: trace_id,
        result_id: document_capture_session.result_id,
        user_id: user_id,
        threatmetrix_session_id: threatmetrix_session_id,
        request_ip: request_ip,
        double_address_verification: double_address_verification,
      }

      if IdentityConfig.store.ruby_workers_idv_enabled
        ResolutionProofingJob.perform_later(**job_arguments)
      else
        ResolutionProofingJob.perform_now(**job_arguments)
      end
    end

    def proof_address(document_capture_session, user_id:, issuer:, trace_id:)
      document_capture_session.create_proofing_session
      encrypted_arguments = Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
        { applicant_pii: @applicant }.to_json,
      )

      job_arguments = {
        user_id: user_id,
        issuer: issuer,
        encrypted_arguments: encrypted_arguments,
        result_id: document_capture_session.result_id,
        trace_id: trace_id,
      }

      if IdentityConfig.store.ruby_workers_idv_enabled
        AddressProofingJob.perform_later(**job_arguments)
      else
        AddressProofingJob.perform_now(**job_arguments)
      end
    end
  end
end
