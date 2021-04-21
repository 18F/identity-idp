class ResolutionProofingJob < ApplicationJob
  queue_as :default

  def perform(result_id:, encrypted_arguments:, trace_id:, should_proof_state_id:,
              dob_year_only:)
    decrypted_args = JSON.parse(
      Encryption::Encryptors::SessionEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    result = Idv::Proofer.resolution_job_class.new(
      applicant_pii: decrypted_args[:applicant_pii],
      should_proof_state_id: should_proof_state_id,
      dob_year_only: dob_year_only,
      logger: logger,
      trace_id: trace_id,
    ).proof

    document_capture_session = DocumentCaptureSession.new(result_id: result_id)
    document_capture_session.store_proofing_result(result[:resolution_result])
  end
end
