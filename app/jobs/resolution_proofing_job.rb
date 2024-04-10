# frozen_string_literal: true

class ResolutionProofingJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :high_resolution_proofing

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  CallbackLogData = Struct.new(
    :result,
    :resolution_success,
    :residential_resolution_success,
    :state_id_success,
    :device_profiling_success,
    keyword_init: true,
  )

  def perform(
    result_id:,
    encrypted_arguments:,
    trace_id:,
    should_proof_state_id:,
    ipp_enrollment_in_progress:,
    user_id: nil,
    threatmetrix_session_id: nil,
    request_ip: nil,
    instant_verify_ab_test_discriminator: nil
  )
    timer = JobHelpers::Timer.new

    raise_stale_job! if stale_job?(enqueued_at)

    decrypted_args = JSON.parse(
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    applicant_pii = decrypted_args[:applicant_pii]

    user = User.find_by(id: user_id)

    callback_log_data = nil
    if IdentityConfig.store.idv_new_identity_resolver_enabled
      callback_log_data = proof_with_new_identity_resolver(
        user: user,
        applicant_pii: applicant_pii,
        request_ip:,
        threatmetrix_session_id: threatmetrix_session_id,
        timer:,
      )
    else
      callback_log_data = make_vendor_proofing_requests(
        timer: timer,
        user: user,
        applicant_pii: applicant_pii,
        threatmetrix_session_id: threatmetrix_session_id,
        request_ip: request_ip,
        should_proof_state_id: should_proof_state_id,
        ipp_enrollment_in_progress: ipp_enrollment_in_progress,
        instant_verify_ab_test_discriminator: instant_verify_ab_test_discriminator,
      )
    end

    document_capture_session = DocumentCaptureSession.new(result_id: result_id)
    document_capture_session.store_proofing_result(callback_log_data.result)
  ensure
    logger_info_hash(
      name: 'ProofResolution',
      trace_id: trace_id,
      resolution_success: callback_log_data&.resolution_success,
      residential_resolution_success: callback_log_data&.residential_resolution_success,
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
    should_proof_state_id:,
    ipp_enrollment_in_progress:,
    instant_verify_ab_test_discriminator:
  )

    result = resolution_proofer(instant_verify_ab_test_discriminator).proof(
      applicant_pii: applicant_pii,
      user_email: user&.confirmed_email_addresses&.first&.email,
      threatmetrix_session_id: threatmetrix_session_id,
      request_ip: request_ip,
      should_proof_state_id: should_proof_state_id,
      ipp_enrollment_in_progress: ipp_enrollment_in_progress,
      timer: timer,
    )

    log_threatmetrix_info(result.device_profiling_result, user)
    add_threatmetrix_proofing_component(user.id, result.device_profiling_result) if user.present?

    CallbackLogData.new(
      device_profiling_success: result.device_profiling_result.success?,
      resolution_success: result.resolution_result.success?,
      residential_resolution_success: result.residential_resolution_result.success?,
      result: result.adjudicated_result.to_h,
      state_id_success: result.state_id_result.success?,
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

  # @return [CallbackLogData]
  def proof_with_new_identity_resolver(
    applicant_pii:,
    request_ip:,
    threatmetrix_session_id:,
    timer:,
    user:,
    **
  )
    plugins = [
      Idv::Resolution::ThreatmetrixPlugin.new(timer:),
      Idv::Resolution::AamvaPlugin.new,
    ]

    resolver = Idv::Resolution::IdentityResolver.new(plugins:)

    input = Idv::Resolution::Input.from_pii(applicant_pii).
      with(other: {
        email: user&.confirmed_email_addresses&.first&.email,
        threatmetrix_session_id:,
        ip: request_ip,
        ssn: applicant_pii[:ssn],
        sp_app_id: applicant_pii[:uuid_prefix],
      })

    result = resolver.resolve_identity(input:)

    CallbackLogData.new(
      device_profiling_success: nil,
      resolution_success: nil,
      residential_resolution_success: nil,
      result:,
      state_id_success: nil,
    )
  end

  def resolution_proofer(instant_verify_ab_test_discriminator)
    @resolution_proofer ||= Proofing::Resolution::ProgressiveProofer.
      new(instant_verify_ab_test_discriminator)
  end

  def add_threatmetrix_proofing_component(user_id, threatmetrix_result)
    ProofingComponent.
      create_or_find_by(user_id: user_id).
      update(threatmetrix: FeatureManagement.proofing_device_profiling_collecting_enabled?,
             threatmetrix_review_status: threatmetrix_result.review_status)
  end
end
