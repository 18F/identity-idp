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
end
