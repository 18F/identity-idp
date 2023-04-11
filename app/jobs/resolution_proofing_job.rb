class ResolutionProofingJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :high_resolution_proofing

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  CallbackLogData = Struct.new(
    :result,
    :resolution_success,
    :state_id_success,
    keyword_init: true,
  )

  def perform(
    result_id:,
    encrypted_arguments:,
    trace_id:,
    should_proof_state_id:,
    capture_secondary_id_enabled: false,
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

    @resolution_proofer = Proofing::Resolution::Proofer.new(
      should_proof_state_id: should_proof_state_id,
      capture_secondary_id_enabled: capture_secondary_id_enabled,
    )

    user = User.find_by(id: user_id)

    optional_threatmetrix_result = proof_lexisnexis_ddp_with_threatmetrix_if_needed(
      applicant_pii: applicant_pii,
      user: user,
      threatmetrix_session_id: threatmetrix_session_id,
      request_ip: request_ip,
      timer: timer,
    )

    callback_log_data = proof_lexisnexis_then_aamva(
      timer: timer,
      applicant_pii: applicant_pii,
    )

    if optional_threatmetrix_result.present?
      add_threatmetrix_result_to_callback_result(
        callback_log_data: callback_log_data,
        threatmetrix_result: optional_threatmetrix_result,
      )
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

  attr_reader :resolution_proofer

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

  def add_threatmetrix_result_to_callback_result(callback_log_data:, threatmetrix_result:)
    exception = threatmetrix_result.exception.inspect if threatmetrix_result.exception

    callback_log_data.result[:context][:stages][:threatmetrix] = threatmetrix_result.to_h

    if exception.present?
      callback_log_data.result.merge!(
        success: false,
        exception: exception,
      )
    end
  end

  def proof_lexisnexis_ddp_with_threatmetrix_if_needed(
    applicant_pii:,
    user:,
    threatmetrix_session_id:,
    request_ip:,
    timer:
  )
    return unless FeatureManagement.proofing_device_profiling_collecting_enabled?

    # The API call will fail without a session ID, so do not attempt to make
    # it to avoid leaking data when not required.
    return if threatmetrix_session_id.blank?

    return unless applicant_pii

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

  # @return [CallbackLogData]
  def proof_lexisnexis_then_aamva(applicant_pii:, timer:)
    result = resolution_proofer.proof(applicant_pii: applicant_pii, timer: timer)

    CallbackLogData.new(
      resolution_success: result.resolution_result.success?,
      result: result.adjudicated_result.to_h,
      state_id_success: result.state_id_result.success?,
    )
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

  def add_threatmetrix_proofing_component(user_id, threatmetrix_result)
    ProofingComponent.
      create_or_find_by(user_id: user_id).
      update(threatmetrix: true,
             threatmetrix_review_status: threatmetrix_result.review_status)
  end
end
