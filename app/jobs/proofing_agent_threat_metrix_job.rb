# frozen_string_literal: true

class ProofingAgentThreatMetrixJob < ApplicationJob
  def perform(
    user_id:,
    applicant_pii:,
    request_ip:,
    threatmetrix_session_id:,
    timer:,
    current_sp:,
    workflow:
  )
    user = User.find_by(id: user_id)

    device_profiling_result = nil
    if !FeatureManagement.proofing_agent_device_profiling_collecting_enabled?
      device_profiling_result = threatmetrix_plugin.threatmetrix_disabled_result
    end

    device_profiling_result ||= threatmetrix_plugin.call(
      applicant_pii:,
      request_ip:,
      threatmetrix_session_id:,
      timer:,
      current_sp:,
      workflow:,
      user_email: user&.last_sign_in_email_address&.email,
      user_uuid: user&.uuid,
      ddp_policy: IdentityConfig.store.lexisnexis_threatmetrix_policy,
    )

    store_device_profiling_result(user_id, device_profiling_result)

    log_attempt(user:, sp: current_sp, result: device_profiling_result)

    analytics(user).idv_proofing_agent_tmx_result(**device_profiling_result.to_h)
  end

  def analytics(user)
    Analytics.new(user: user, request: nil, session: {}, sp: nil)
  end

  private

  def threatmetrix_plugin
    @threatmetrix_plugin ||= Proofing::Resolution::Plugins::ThreatMetrixPlugin.new
  end

  def store_device_profiling_result(user_id, result)
    return unless user_id.present?
    return unless IdentityConfig.store.proofing_agent_device_profiling == :enabled

    device_profiling_result = DeviceProfilingResult.find_or_create_by(
      user_id:,
      profiling_type: DeviceProfilingResult::PROFILING_TYPES[:proofing_agent],
    )
    device_profiling_result.update(
      client: result.client,
      review_status: result.review_status,
      transaction_id: result.transaction_id,
    )
  end

  def log_attempt(user:, sp:, result:)
    return unless FeatureManagement.proofing_agent_device_profiling_collecting_enabled?

    attempts_api_tracker(user, sp).idv_device_risk_assessment(
      success: result.success,
      device_fingerprint: result.device_fingerprint,
      failure_reason: device_risk_failure_reason(result),
    )
  end

  def attempts_api_tracker(user, sp)
    AttemptsApi::Tracker.new(
      enabled_for_session: sp.attempts_api_enabled?,
      session_id: nil,
      request: nil,
      user:,
      sp: sp,
      cookie_device_uuid: nil,
      sp_redirect_uri: nil,
    )
  end

  def device_risk_failure_reason(result)
    return nil if result.success

    fraud_risk_summary_reason_code = result.response_body&.dig(
      'tmx_summary_reason_code',
    ) || ['Fraud risk assessment has failed for unknown reasons']

    { fraud_risk_summary_reason_code: }
  end
end
