# frozen_string_literal: true

class AccountCreationThreatMetrixJob < ApplicationJob
  def perform(
    user_id: nil,
    threatmetrix_session_id: nil,
    request_ip: nil,
    email: nil
  )

    device_profiling_result = AccountCreation::DeviceProfiling.new.proof(
      request_ip: request_ip,
      threatmetrix_session_id: threatmetrix_session_id,
      user_email: email,
    )
  ensure
    user = User.find_by(id: user_id)
    analytics(user).account_creation_tmx_result(**device_profiling_result)
  end

  def analytics(user)
    Analytics.new(user: user, request: nil, session: {}, sp: nil)
  end
end
