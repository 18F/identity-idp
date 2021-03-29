module Idv
  class Agent
    def initialize(applicant)
      @applicant = applicant.symbolize_keys
    end

    def proof_resolution(document_capture_session, should_proof_state_id:, trace_id:)
      document_capture_session.create_proofing_session
      callback_url = Rails.application.routes.url_helpers.resolution_proof_result_url(
        document_capture_session.result_id,
      )

      encrypted_arguments = Encryption::Encryptors::SessionEncryptor.new.encrypt(
        { applicant_pii: @applicant }.to_json,
      )

      if FeatureManagement.ruby_workers_enabled?
        ResolutionProofingJob.perform_later(
          encrypted_arguments: encrypted_arguments,
          callback_url: callback_url,
          should_proof_state_id: should_proof_state_id,
          dob_year_only: AppConfig.env.proofing_send_partial_dob == 'true',
          trace_id: trace_id,
          result_id: document_capture_session.result_id,
        )
      else
        ResolutionProofingJob.perform_now(
          encrypted_arguments: encrypted_arguments,
          callback_url: callback_url,
          should_proof_state_id: should_proof_state_id,
          dob_year_only: AppConfig.env.proofing_send_partial_dob == 'true',
          trace_id: trace_id,
          result_id: document_capture_session.result_id,
        )
      end
    end

    def proof_address(document_capture_session, trace_id:)
      document_capture_session.create_proofing_session
      callback_url = Rails.application.routes.url_helpers.address_proof_result_url(
        document_capture_session.result_id,
      )
      encrypted_arguments = Encryption::Encryptors::SessionEncryptor.new.encrypt(
        { applicant_pii: @applicant }.to_json,
      )

      if FeatureManagement.ruby_workers_enabled?
        AddressProofingJob.perform_later(
          encrypted_arguments: encrypted_arguments,
          callback_url: callback_url,
          result_id: document_capture_session.result_id,
          trace_id: trace_id,
        )
      else
        AddressProofingJob.perform_now(
          encrypted_arguments: encrypted_arguments,
          callback_url: callback_url,
          result_id: document_capture_session.result_id,
          trace_id: trace_id,
        )
      end
    end

    def proof_document(document_capture_session, liveness_checking_enabled:, trace_id:)
      callback_url = Rails.application.routes.url_helpers.document_proof_result_url(
        result_id: document_capture_session.result_id,
      )

      encrypted_arguments = Encryption::Encryptors::SessionEncryptor.new.encrypt(
        { document_arguments: @applicant }.to_json,
      )

      if FeatureManagement.ruby_workers_enabled?
        DocumentProofingJob.perform_later(
          encrypted_arguments: encrypted_arguments,
          liveness_checking_enabled: liveness_checking_enabled,
          result_id: document_capture_session.result_id,
          callback_url: callback_url,
          trace_id: trace_id,
        )
      else
        DocumentProofingJob.perform_now(
          encrypted_arguments: encrypted_arguments,
          liveness_checking_enabled: liveness_checking_enabled,
          result_id: document_capture_session.result_id,
          callback_url: callback_url,
          trace_id: trace_id,
        )
      end
    end
  end
end
