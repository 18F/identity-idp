class AddressProofingJob < ApplicationJob
  queue_as :default

  def perform(result_id:, encrypted_arguments:, trace_id:)
    decrypted_args = JSON.parse(
      Encryption::Encryptors::SessionEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    result = Idv::Proofer.address_job_class.new(
      applicant_pii: decrypted_args[:applicant_pii],
      logger: logger,
      trace_id: trace_id,
    ).proof

    document_capture_session = DocumentCaptureSession.new(result_id: result_id)
    document_capture_session.store_proofing_result(result[:address_result])
  end
end
