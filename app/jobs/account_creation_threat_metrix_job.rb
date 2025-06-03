# frozen_string_literal: true

class AccountCreationThreatMetrixJob < ApplicationJob
  def perform(
    user_id: nil,
    threatmetrix_session_id: nil,
    request_ip: nil,
    email: nil,
    uuid_prefix: nil,
    user_uuid: nil
  )
    device_profiling_result = AccountCreation::DeviceProfiling.new.proof(
      request_ip: request_ip,
      threatmetrix_session_id: threatmetrix_session_id,
      user_email: email,
      uuid_prefix: uuid_prefix,
      uuid: user_uuid,
      workflow: :auth,
    )
  ensure
    user = User.find_by(id: user_id)
    store_device_profiling_result(user_id, result)
    analytics(user).account_creation_tmx_result(**device_profiling_result.to_h)
  end

  def analytics(user)
    Analytics.new(user: user, request: nil, session: {}, sp: nil)
  end

  private

  def store_device_profiling_result(user_id, result)
    return unless user_id.present?
    device_profiling_result = DeviceProfilingResult.find_or_create_by(
      user_id:,
      profiling_type: DeviceProfilingResult::PROFILING_TYPES[:account_creation],
    )
    device_profiling_result.update(
      success: result.success?,
      client: result.client,
      review_status: result.review_status,
      transaction_id: result.transaction_id,
      reason: result.review_status,
    )
  end
end
