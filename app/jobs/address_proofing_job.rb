class AddressProofingJob < ApplicationJob
  queue_as :default

  def perform(result_id:, encrypted_arguments:, callback_url:, trace_id:)
    decrypted_args = JSON.parse(
      Encryption::Encryptors::SessionEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    Idv::Proofer.address_job_class.handle(
      event: {
        applicant_pii: decrypted_args[:applicant_pii],
        callback_url: :callback_url,
        trace_id: :trace_id,
        lexisnexis_config: {
          phone_finder_workflow: AppConfig.env.lexisnexis_phone_finder_workflow,
          account_id: AppConfig.env.lexisnexis_account_id,
          base_url: AppConfig.env.lexisnexis_base_url,
          username: AppConfig.env.lexisnexis_username,
          password: AppConfig.env.lexisnexis_password,
          request_mode: AppConfig.env.lexisnexis_request_mode,
          request_timeout: AppConfig.env.lexisnexis_timeout,
        },
      },
      context: nil,
    ) do |result|
      document_capture_session = DocumentCaptureSession.new(result_id: result_id)
      document_capture_session.store_proofing_result(result[:address_result])
    end
  end
end
