# frozen_string_literal: true

module Idv
  class Agent
    def initialize(applicant)
      @applicant = applicant.symbolize_keys
    end

    def proof_resolution(
      document_capture_session,
      trace_id:,
      threatmetrix_session_id:,
      request_ip:,
      ipp_enrollment_in_progress:,
      proofing_vendor:,
      state_id_already_proofed: false,
      hybrid_mobile_threatmetrix_session_id: nil,
      hybrid_mobile_request_ip: nil
    )
      document_capture_session.create_proofing_session

      encrypted_arguments = Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
        { applicant_pii: @applicant }.to_json,
      )

      job_arguments = {
        encrypted_arguments:,
        trace_id:,
        result_id: document_capture_session.result_id,
        user_id: document_capture_session.user_id,
        service_provider_issuer: document_capture_session.issuer,
        threatmetrix_session_id:,
        request_ip:,
        hybrid_mobile_threatmetrix_session_id:,
        hybrid_mobile_request_ip:,
        ipp_enrollment_in_progress:,
        proofing_vendor:,
        state_id_already_proofed:,
      }

      if IdentityConfig.store.ruby_workers_idv_enabled
        ResolutionProofingJob.perform_later(**job_arguments)
      else
        ResolutionProofingJob.perform_now(**job_arguments)
      end
    end

    def proof_address(document_capture_session, issuer:, trace_id:)
      document_capture_session.create_proofing_session
      encrypted_arguments = Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
        { applicant_pii: @applicant }.to_json,
      )

      job_arguments = {
        user_id: document_capture_session.user_id,
        issuer: issuer,
        encrypted_arguments: encrypted_arguments,
        result_id: document_capture_session.result_id,
        trace_id: trace_id,
        address_vendor: IdentityConfig.store.idv_address_primary_vendor, # remove: 50/50
      }

      if IdentityConfig.store.ruby_workers_idv_enabled
        AddressProofingJob.perform_later(**job_arguments)
      else
        AddressProofingJob.perform_now(**job_arguments)
      end
    end
  end
end
