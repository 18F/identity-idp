# frozen_string_literal: true

class AccountCreationThreatMetrixJob < ApplicationJob
  def perform(
    user_id: nil,
    threatmetrix_session_id: nil,
    request_ip: nil,
    email: nil,
    uuid_prefix: nil,
    user_uuid: nil,
    workflow: nil
  )
    device_profiling_result = AccountCreation::DeviceProfiling.new.proof(
      request_ip: request_ip,
      threatmetrix_session_id: threatmetrix_session_id,
      user_email: email,
      uuid_prefix: uuid_prefix,
      uuid: user_uuid,
      workflow: workflow,
    )
  ensure
    user = User.find_by(id: user_id)
    analytics(user).account_creation_tmx_result(**device_profiling_result.to_h)
  end

  def analytics(user)
    Analytics.new(user: user, request: nil, session: {}, sp: nil)
  end
end
