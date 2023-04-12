class ResolutionProofingJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :high_resolution_proofing

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  CallbackLogData = Struct.new(
    :result,
    :resolution_success,
    :state_id_success,
    :device_profiling_success,
    keyword_init: true,
  )

  def perform(
    result_id:,
    encrypted_arguments:,
    trace_id:,
    should_proof_state_id:,
    user_id: nil,
    threatmetrix_session_id: nil,
    request_ip: nil
  )
    timer = JobHelpers::Timer.new

    raise_stale_job! if stale_job?(enqueued_at)

    decrypted_args = JSON.parse(
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    applicant_pii = decrypted_args[:applicant_pii]

    user = User.find_by(id: user_id)

    callback_log_data = make_vendor_proofing_requests(
      timer: timer,
      user: user,
      applicant_pii: applicant_pii,
      threatmetrix_session_id: threatmetrix_session_id,
      request_ip: request_ip,
      should_proof_state_id: should_proof_state_id,
    )

    document_capture_session = DocumentCaptureSession.new(result_id: result_id)
    document_capture_session.store_proofing_result(callback_log_data.result)
  ensure
    logger_info_hash(
      name: 'ProofResolution',
      trace_id: trace_id,
      resolution_success: callback_log_data&.resolution_success,
      state_id_success: callback_log_data&.state_id_success,
      device_profiling_success: callback_log_data&.device_profiling_success,
      timing: timer.results,
    )
  end

  private

  # @return [CallbackLogData]
  def make_vendor_proofing_requests(
    timer:,
    user:,
    applicant_pii:,
    threatmetrix_session_id:,
    request_ip:,
    should_proof_state_id:
  )
    device_profiling_result = proof_with_threatmetrix_if_needed(
      applicant_pii: applicant_pii,
      user: user,
      threatmetrix_session_id: threatmetrix_session_id,
      request_ip: request_ip,
      timer: timer,
    )

    resolution_result = timer.time('resolution') do
      resolution_proofer.proof(applicant_pii)
    end

    state_id_result = Proofing::StateIdResult.new(
      success: true, errors: {}, exception: nil, vendor_name: 'UnsupportedJurisdiction',
    )
    if should_proof_state_id && user_can_pass_after_state_id_check?(resolution_result)
      timer.time('state_id') do
        state_id_result = state_id_proofer.proof(applicant_pii)
      end
    end

    result = Proofing::ResolutionResultAdjudicator.new(
      resolution_result: resolution_result,
      state_id_result: state_id_result,
      should_proof_state_id: should_proof_state_id,
      device_profiling_result: device_profiling_result,
    ).adjudicated_result.to_h

    CallbackLogData.new(
      result: result,
      resolution_success: resolution_result.success?,
      state_id_success: state_id_result.success?,
      device_profiling_success: device_profiling_result.success?,
    )
  end

  def proof_with_threatmetrix_if_needed(
    applicant_pii:,
    user:,
    threatmetrix_session_id:,
    request_ip:,
    timer:
  )
    if !FeatureManagement.proofing_device_profiling_collecting_enabled?
      return threatmetrix_disabled_result
    end

    # The API call will fail without a session ID, so do not attempt to make
    # it to avoid leaking data when not required.
    return threatmetrix_disabled_result if threatmetrix_session_id.blank?

    return threatmetrix_disabled_result unless applicant_pii

    ddp_pii = applicant_pii.dup
    ddp_pii[:threatmetrix_session_id] = threatmetrix_session_id
    ddp_pii[:email] = user&.confirmed_email_addresses&.first&.email
    ddp_pii[:request_ip] = request_ip

    result = timer.time('threatmetrix') do
      lexisnexis_ddp_proofer.proof(ddp_pii)
    end

    log_threatmetrix_info(result, user)
    add_threatmetrix_proofing_component(user.id, result)

    result
  end

  def threatmetrix_disabled_result
    Proofing::DdpResult.new(
      success: true,
      client: 'tmx_disabled',
      review_status: 'pass',
    )
  end

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

  def user_can_pass_after_state_id_check?(resolution_result)
    return true if resolution_result.success?
    # For failed IV results, this method validates that the user is eligible to pass if the
    # failed attributes are covered by the same attributes in a successful AAMVA response
    # aka the Get-to-Yes w/ AAMVA feature.
    return false unless resolution_result.failed_result_can_pass_with_additional_verification?

    attributes_aamva_can_pass = [:address, :dob, :state_id_number]
    results_that_cannot_pass_aamva =
      resolution_result.attributes_requiring_additional_verification - attributes_aamva_can_pass

    results_that_cannot_pass_aamva.blank?
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

  def add_threatmetrix_proofing_component(user_id, threatmetrix_result)
    ProofingComponent.
      create_or_find_by(user_id: user_id).
      update(threatmetrix: true,
             threatmetrix_review_status: threatmetrix_result.review_status)
  end
end
