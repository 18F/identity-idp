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

      if FeatureManagement.use_ruby_workers?
        encrypted_arguments = Encryption::Encryptors::SessionEncryptor.new.encrypt(
          { applicant_pii: @applicant }.to_json,
        )

        ResolutionProofingJob.perform_now(
          encrypted_arguments: encrypted_arguments,
          callback_url: callback_url,
          should_proof_state_id: should_proof_state_id,
          dob_year_only: AppConfig.env.proofing_send_partial_dob == 'true',
          trace_id: trace_id,
          result_id: document_capture_session.result_id,
        )
      else
        LambdaJobs::Runner.new(
          job_class: Idv::Proofer.resolution_job_class,
          in_process_config: {
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
          args: {
            applicant_pii: @applicant,
            callback_url: callback_url,
            should_proof_state_id: should_proof_state_id,
            dob_year_only: AppConfig.env.proofing_send_partial_dob == 'true',
            trace_id: trace_id,
          },
        ).run do |idv_result|
          document_capture_session.store_proofing_result(idv_result[:resolution_result])

          nil
        end
      end
    end

    def proof_address(document_capture_session, trace_id:)
      document_capture_session.create_proofing_session
      callback_url = Rails.application.routes.url_helpers.address_proof_result_url(
        document_capture_session.result_id,
      )

      if FeatureManagement.use_ruby_workers?
        encrypted_arguments = Encryption::Encryptors::SessionEncryptor.new.encrypt(
          { applicant_pii: @applicant }.to_json,
        )
        AddressProofingJob.perform_now(
          encrypted_arguments: encrypted_arguments,
          callback_url: callback_url,
          result_id: document_capture_session.result_id,
          trace_id: trace_id,
        )
      else
        LambdaJobs::Runner.new(
          job_class: Idv::Proofer.address_job_class,
          in_process_config: {
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
          args: { applicant_pii: @applicant, callback_url: callback_url, trace_id: trace_id },
          in_process_config: {
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
        ).run do |idv_result|
          document_capture_session.store_proofing_result(idv_result[:address_result])

          nil
        end
      end
    end

    def proof_document(document_capture_session, liveness_checking_enabled:, trace_id:)
      callback_url = Rails.application.routes.url_helpers.document_proof_result_url(
        result_id: document_capture_session.result_id,
      )

      if FeatureManagement.use_ruby_workers?
        encrypted_arguments = Encryption::Encryptors::SessionEncryptor.new.encrypt(
          @applicant.to_json,
        )

        DocumentProofingJob.perform_now(
          encrypted_arguments: encrypted_arguments,
          liveness_checking_enabled: liveness_checking_enabled,
          result_id: document_capture_session.result_id,
          callback_url: callback_url,
          trace_id: trace_id,
        )
      else
        LambdaJobs::Runner.new(
          job_class: Idv::Proofer.document_job_class,
          args: {
            encryption_key: @applicant[:encryption_key],
            front_image_iv: @applicant[:front_image_iv],
            back_image_iv: @applicant[:back_image_iv],
            selfie_image_iv: @applicant[:selfie_image_iv],
            front_image_url: @applicant[:front_image_url],
            back_image_url: @applicant[:back_image_url],
            selfie_image_url: @applicant[:selfie_image_url],
            liveness_checking_enabled: liveness_checking_enabled,
            callback_url: callback_url,
            trace_id: trace_id,
          },
          in_process_config: {
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
        ).run do |doc_auth_result|
            document_result = doc_auth_result.to_h.fetch(:document_result, {})
            dcs = DocumentCaptureSession.new(result_id: document_capture_session.result_id)
            dcs.store_doc_auth_result(
              result: document_result.except(:pii_from_doc),
              pii: document_result[:pii_from_doc],
            )

            nil
          end
      end
    end

    private

    def init_results
      {
        errors: {},
        messages: [],
        context: {
          stages: [],
        },
        exception: nil,
        success: false,
        timed_out: false,
      }
    end
  end
end
