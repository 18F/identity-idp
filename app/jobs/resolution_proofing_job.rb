class ResolutionProofingJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :default

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  CallbackLogData = Struct.new(
    :result,
    :resolution_success,
    :state_id_success,
    keyword_init: true,
  )

  def perform(result_id:, encrypted_arguments:, trace_id:, should_proof_state_id:,
              dob_year_only:, user_id: nil, threatmetrix_session_id: nil)
    timer = JobHelpers::Timer.new

    raise_stale_job! if stale_job?(enqueued_at)

    decrypted_args = JSON.parse(
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    applicant_pii = decrypted_args[:applicant_pii]

    optional_threatmetrix_result = proof_lexisnexis_ddp_with_threatmetrix_if_needed(
      applicant_pii,
      user_id,
      threatmetrix_session_id,
    )

    callback_log_data = if dob_year_only && should_proof_state_id
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
                          )
                        end

    if optional_threatmetrix_result.present?
      add_threatmetrix_result_to_callback_result(callback_log_data.result, optional_threatmetrix_result)
    end

    document_capture_session = DocumentCaptureSession.new(result_id: result_id)
    document_capture_session.store_proofing_result(callback_log_data.result)
  ensure
    logger_info_hash(
      name: 'ProofResolution',
      trace_id: trace_id,
      resolution_success: callback_log_data&.resolution_success,
      state_id_success: callback_log_data&.state_id_success,
      timing: timer.results,
    )
  end

  private

  def log_threatmetrix_info(threatmetrix_result, user)
    logger_info_hash(
      name: 'ThreatMetrix',
      user_id: user&.uuid,
      threatmetrix_request_id: threatmetrix_result.transaction_id,
      threatmetrix_success: threatmetrix_result.success?,
    )
  end

  def logger_info_hash(hash)
    logger.info(hash.to_json)
  end

  def add_threatmetrix_result_to_callback_result(callback_log_data_result, threatmetrix_result)
    callback_log_data_result[:threatmetrix_success] = threatmetrix_result.success?
    callback_log_data_result[:threatmetrix_request_id] = threatmetrix_result.transaction_id
  end

  def proof_lexisnexis_ddp_with_threatmetrix_if_needed(applicant_pii, user_id, threatmetrix_session_id)
    return unless IdentityConfig.store.lexisnexis_threatmetrix_enabled

    # The API call will fail without a session ID, so do not attempt to make
    # it to avoid leaking data when not required.
    return if threatmetrix_session_id.blank?

    return unless applicant_pii

    user = User.find_by(id: user_id)

    ddp_pii = applicant_pii.dup
    ddp_pii[:threatmetrix_session_id] = threatmetrix_session_id
    ddp_pii[:email] = user&.confirmed_email_addresses&.first&.email

    result = lexisnexis_ddp_proofer.proof(ddp_pii)

    log_threatmetrix_info(result, user)

    result
  end

  # @return [CallbackLogData]
  def proof_lexisnexis_then_aamva(timer:, applicant_pii:, should_proof_state_id:)
    proofer_result = timer.time('resolution') do
      resolution_proofer.proof(applicant_pii)
    end

    result = proofer_result.to_h
    resolution_success = proofer_result.success?

    result[:transaction_id] = proofer_result.transaction_id
    result[:reference] = proofer_result.reference

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
          reference: proofer_result.reference,
        },
      },
    }

    state_id_success = nil
    if should_proof_state_id && result[:success]
      timer.time('state_id') do
        proof_state_id(applicant_pii: applicant_pii, result: result)
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
      state_id_proofer.proof(applicant_pii)
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
        resolution_proofer.proof(applicant_pii.merge(dob_year_only: dob_year_only))
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
        reference: lexisnexis_result.reference,
      }

      result[:transaction_id] = lexisnexis_result.transaction_id
      result[:reference] = lexisnexis_result.reference
      result[:timed_out] = lexisnexis_result.timed_out?
      result[:exception] = lexisnexis_result.exception.inspect if lexisnexis_result.exception
    end

    CallbackLogData.new(
      result: result,
      resolution_success: resolution_success,
      state_id_success: state_id_success,
    )
  end

  def proof_state_id(applicant_pii:, result:)
    proofer_result = state_id_proofer.proof(applicant_pii)

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
    @resolution_proofer ||=
      if IdentityConfig.store.proofer_mock_fallback
        Proofing::Mock::ResolutionMockClient.new
      else
        Proofing::LexisNexis::InstantVerify::Proofer.new(
          instant_verify_workflow: IdentityConfig.store.lexisnexis_instant_verify_workflow,
          account_id: IdentityConfig.store.lexisnexis_account_id,
          base_url: IdentityConfig.store.lexisnexis_base_url,
          username: IdentityConfig.store.lexisnexis_username,
          password: IdentityConfig.store.lexisnexis_password,
          request_mode: IdentityConfig.store.lexisnexis_request_mode,
        )
      end
  end

  def lexisnexis_ddp_proofer
    @lexisnexis_ddp_proofer ||=
      if IdentityConfig.store.lexisnexis_threatmetrix_mock_enabled
        Proofing::Mock::DdpMockClient.new
      else
        Proofing::LexisNexis::Ddp::Proofer.new(
          api_key: IdentityConfig.store.lexisnexis_threatmetrix_api_key,
          org_id: IdentityConfig.store.lexisnexis_threatmetrix_org_id,
          base_url: IdentityConfig.store.lexisnexis_threatmetrix_base_url,
        )
      end
  end

  def state_id_proofer
    @state_id_proofer ||=
      if IdentityConfig.store.proofer_mock_fallback
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
