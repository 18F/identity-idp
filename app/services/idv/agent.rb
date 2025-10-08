# frozen_string_literal: true

module Idv
  class Agent
    def initialize(applicant)
      @applicant = applicant.symbolize_keys
    end

    # @param document_capture_session [DocumentCaptureSession]
    # @param proofing_components [Idv::ProofingComponents]
    def proof_resolution(
      document_capture_session,
      trace_id:,
      user_id:,
      threatmetrix_session_id:,
      request_ip:,
      ipp_enrollment_in_progress:,
      proofing_components:,
      proofing_vendor:
    )
      document_capture_session.create_proofing_session

      encrypted_arguments = Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
        { applicant_pii: @applicant }.to_json,
      )

      job_arguments = {
        encrypted_arguments:,
        trace_id:,
        result_id: document_capture_session.result_id,
        user_id: user_id,
        service_provider_issuer: document_capture_session.issuer,
        threatmetrix_session_id:,
        request_ip:,
        ipp_enrollment_in_progress:,
        proofing_components: proofing_components.to_h,
        proofing_vendor:,
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

      address_vendor = address_vendor_ab_test_bucket ||
                       IdentityConfig.store.idv_address_default_vendor

      job_arguments = {
        user_id: user_id,
        issuer: issuer,
        encrypted_arguments: encrypted_arguments,
        result_id: document_capture_session.result_id,
        trace_id: trace_id,
        address_vendor:,
      }

      if IdentityConfig.store.ruby_workers_idv_enabled
        AddressProofingJob.perform_later(**job_arguments)
      else
        AddressProofingJob.perform_now(**job_arguments)
      end
    end

    def address_vendor_ab_test_bucket
      AbTests::ADDRESS_PROOFING_VENDOR.bucket(
        request: nil,
        service_provider: nil,
        session: nil,
        user: nil,
        user_session: nil,
      )
    end
  end
end
