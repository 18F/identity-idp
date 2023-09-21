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
    double_address_verification: false,
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
      double_address_verification: double_address_verification,
    )

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
    double_address_verification:
  )
    result = resolution_proofer.proof(
      applicant_pii: applicant_pii,
      user_email: user&.confirmed_email_addresses&.first&.email,
      threatmetrix_session_id: threatmetrix_session_id,
      request_ip: request_ip,
      should_proof_state_id: should_proof_state_id,
      timer: timer,
      double_address_verification: double_address_verification,
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

  def resolution_proofer
    @resolution_proofer ||= Proofing::Resolution::ProgressiveProofer.new
  end

  def add_threatmetrix_proofing_component(user_id, threatmetrix_result)
    ProofingComponent.
      create_or_find_by(user_id: user_id).
      update(threatmetrix: FeatureManagement.proofing_device_profiling_collecting_enabled?,
             threatmetrix_review_status: threatmetrix_result.review_status)
  end
end
