# frozen_string_literal: true

module ProofingAgent
  class ProofUser
    def initialize(applicant)
      @applicant = ProofingAgent::ApplicantPiiTransformer.new(applicant).transform
    end

    def call(
      proofing_agent_id:,
      proofing_location_id:,
      correlation_id:,
      trace_id:,
      transaction_id:,
      proofing_vendor:
    )
      encrypted_arguments = Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
        { applicant_pii: @applicant }.to_json,
      )

      job_arguments = {
        encrypted_arguments:,
        trace_id:,
        proofing_vendor:,
        proofing_agent_id:,
        proofing_location_id:,
        correlation_id:,
        transaction_id:,
      }
      if IdentityConfig.store.ruby_workers_idv_enabled
        ProofingAgentJob.perform_later(**job_arguments)
      else
        ProofingAgentJob.perform_now(**job_arguments)
      end
    end
  end
end
