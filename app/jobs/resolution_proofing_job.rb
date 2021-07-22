class ResolutionProofingJob < ApplicationJob
  include JobHelpers::FaradayHelper

  queue_as :default

  CallbackLogData = Struct.new(
    :result,
    :resolution_success,
    :state_id_success,
    keyword_init: true,
  )

  def perform(result_id:, encrypted_arguments:, trace_id:, should_proof_state_id:,
              dob_year_only:, document_expired:)
    timer = JobHelpers::Timer.new
    decrypted_args = JSON.parse(
      Encryption::Encryptors::SessionEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    applicant_pii = decrypted_args[:applicant_pii]

    callback_log_data = if !document_expired && dob_year_only && should_proof_state_id
                          proof_aamva_then_lexisnexis_dob_only(
                            timer: timer,
                            applicant_pii: applicant_pii,
                            dob_year_only: dob_year_only,
                          )
                        else
                          proof_lexisnexis_then_aamva(
                            timer: timer,
                            applicant_pii: applicant_pii,
                            should_proof_state_id: should_proof_state_id,
                            document_expired: document_expired,
                          )
                        end


    document_capture_session = DocumentCaptureSession.new(result_id: result_id)
    document_capture_session.store_proofing_result(callback_log_data.result)
  ensure
    logger.info(
      {
        name: 'ProofResolution',
        trace_id: trace_id,
        resolution_success: callback_log_data&.resolution_success,
        state_id_success: callback_log_data&.state_id_success,
        timing: timer.results,
      }.to_json,
    )
  end

  private

  # @return [CallbackLogData]
  def proof_lexisnexis_then_aamva(timer:, applicant_pii:, should_proof_state_id:, document_expired:)
    proofer_result = timer.time('resolution') do
      with_retries(**faraday_retry_options) do
        resolution_proofer.proof(applicant_pii)
      end
    end

    result = proofer_result.to_h
    resolution_success = proofer_result.success?

    result[:transaction_id] = proofer_result.transaction_id

    exception = proofer_result.exception.inspect if proofer_result.exception
    result[:timed_out] = proofer_result.timed_out?
    result[:exception] = exception

    result[:context] = {
      dob_year_only: false,
      should_proof_state_id: should_proof_state_id,
      stages: {
        resolution: {
          client: resolution_proofer.class.vendor_name,
          errors: proofer_result.errors,
          exception: exception,
          success: proofer_result.success?,
          timed_out: proofer_result.timed_out?,
          transaction_id: proofer_result.transaction_id,
        },
      },
    }

    state_id_success = nil
    if should_proof_state_id && result[:success] && !document_expired
      timer.time('state_id') do
        proof_state_id(timer: timer, applicant_pii: applicant_pii, result: result)
      end
      state_id_success = result[:success]
    end

    CallbackLogData.new(
      result: result,
      resolution_success: resolution_success,
      state_id_success: state_id_success,
    )
  end

  # @return [CallbackLogData]
  def proof_aamva_then_lexisnexis_dob_only(timer:, applicant_pii:, dob_year_only:)
    proofer_result = timer.time('state_id') do
      with_retries(**faraday_retry_options) do
        state_id_proofer.proof(applicant_pii)
      end
    end

    result = proofer_result.to_h
    state_id_success = proofer_result.success?
    resolution_success = nil
    exception = proofer_result.exception.inspect if proofer_result.exception

    result[:context] = {
      dob_year_only: dob_year_only,
      should_proof_state_id: true,
      stages: {
        state_id: {
          client: state_id_proofer.class.vendor_name,
          errors: proofer_result.errors,
          exception: exception,
          success: state_id_success,
          timed_out: proofer_result.timed_out?,
          transaction_id: proofer_result.transaction_id,
        },
      },
    }

    if state_id_success
      lexisnexis_result = timer.time('resolution') do
        with_retries(**faraday_retry_options) do
          resolution_proofer.proof(applicant_pii.merge(dob_year_only: dob_year_only))
        end
      end

      resolution_success = lexisnexis_result.success?
      exception = lexisnexis_result.exception.inspect if lexisnexis_result.exception

      result.merge!(lexisnexis_result.to_h) do |key, orig, current|
        key == :messages ? orig + current : current
      end

      result[:context][:stages][:resolution] = {
        client: resolution_proofer.class.vendor_name,
        errors: lexisnexis_result.errors,
        exception: exception,
        success: lexisnexis_result.success?,
        timed_out: lexisnexis_result.timed_out?,
        transaction_id: lexisnexis_result.transaction_id,
      }

      result[:transaction_id] = lexisnexis_result.transaction_id
      result[:timed_out] = lexisnexis_result.timed_out?
      result[:exception] = lexisnexis_result.exception.inspect if lexisnexis_result.exception
    end

    CallbackLogData.new(
      result: result,
      resolution_success: resolution_success,
      state_id_success: state_id_success,
    )
  end

  def proof_state_id(timer:, applicant_pii:, result:)
    proofer_result = with_retries(**faraday_retry_options) do
      state_id_proofer.proof(applicant_pii)
    end

    result.merge!(proofer_result.to_h) do |key, orig, current|
      key == :messages ? orig + current : current
    end

    exception = proofer_result.exception.inspect if proofer_result.exception
    result[:timed_out] = proofer_result.timed_out?
    result[:exception] = exception

    result[:context][:stages][:state_id] = {
      client: state_id_proofer.class.vendor_name,
      errors: proofer_result.errors,
      success: proofer_result.success?,
      timed_out: proofer_result.timed_out?,
      exception: exception,
      transaction_id: proofer_result.transaction_id,
    }

    result
  end

  def resolution_proofer
    @resolution_proofer ||= if IdentityConfig.store.proofer_mock_fallback
      Proofing::Mock::ResolutionMockClient.new
    else
      Proofing::LexisNexis::InstantVerify::Proofer.new(
        instant_verify_workflow: IdentityConfig.store.lexisnexis_instant_verify_workflow,
        account_id: IdentityConfig.store.lexisnexis_account_id,
        base_url: IdentityConfig.store.lexisnexis_base_url,
        username: IdentityConfig.store.lexisnexis_username,
        password: IdentityConfig.store.lexisnexis_password,
        request_mode: IdentityConfig.store.lexisnexis_request_mode,
        request_timeout: IdentityConfig.store.lexisnexis_timeout,
      )
    end
  end

  def state_id_proofer
    @state_id_proofer ||= if IdentityConfig.store.proofer_mock_fallback
      Proofing::Mock::StateIdMockClient.new
    else
      Proofing::Aamva::Proofer.new(
        auth_request_timeout: IdentityConfig.store.aamva_auth_request_timeout,
        auth_url: IdentityConfig.store.aamva_auth_url,
        cert_enabled: IdentityConfig.store.aamva_cert_enabled,
        private_key: IdentityConfig.store.aamva_private_key,
        public_key: IdentityConfig.store.aamva_public_key,
        verification_request_timeout: IdentityConfig.store.aamva_verification_request_timeout,
        verification_url: IdentityConfig.store.aamva_verification_url,
      )
    end
  end
end
