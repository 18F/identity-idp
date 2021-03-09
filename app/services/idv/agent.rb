module Idv
  class Agent
    def initialize(applicant)
      @applicant = applicant.symbolize_keys
    end

    def proof_resolution(document_capture_session, should_proof_state_id:, trace_id:)
      callback_url = Rails.application.routes.url_helpers.resolution_proof_result_url(
        document_capture_session.result_id,
      )

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

    def proof_address(document_capture_session, trace_id:)
      callback_url = Rails.application.routes.url_helpers.address_proof_result_url(
        document_capture_session.result_id,
      )

      LambdaJobs::Runner.new(
        job_class: Idv::Proofer.address_job_class,
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
