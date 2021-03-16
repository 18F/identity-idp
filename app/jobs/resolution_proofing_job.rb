class ResolutionProofingJob < ApplicationJob
  queue_as :default

  def perform(args)
    result_id = args[:result_id]
    encrypted_arguments_ciphertext = args[:encrypted_arguments]
    decrypted_args = JSON.parse(
      Encryption::Encryptors::SessionEncryptor.new.decrypt(encrypted_arguments_ciphertext),
    )

    Idv::Proofer.resolution_job_class.handle(
      event: {
        applicant_pii: decrypted_args['applicant_pii'],
        callback_url: args[:callback_url],
        should_proof_state_id: args[:should_proof_state_id],
        dob_year_only: args[:dob_year_only],
        trace_id: args[:trace_id],
        aamva_config: {
          auth_request_timeout: AppConfig.env.aamva_auth_request_timeout,
          auth_url: AppConfig.env.aamva_auth_url,
          cert_enabled: AppConfig.env.aamva_cert_enabled,
          private_key: AppConfig.env.aamva_private_key,
          public_key: AppConfig.env.aamva_public_key,
          verification_request_timeout: AppConfig.env.aamva_verification_request_timeout,
          verification_url: AppConfig.env.aamva_verification_url,
        },
        lexisnexis_config: {
          instant_verify_workflow: AppConfig.env.lexisnexis_instant_verify_workflow,
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
      document_capture_session.store_proofing_result(result[:resolution_result])
    end
  end
end
