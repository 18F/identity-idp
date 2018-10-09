module AccountResetHelper
  def create_account_reset_request_for(user)
    request = AccountResetRequest.find_or_create_by(user: user)
    request_token = SecureRandom.uuid
    request.update!(
      request_token: request_token,
      requested_at: Time.zone.now,
      cancelled_at: nil,
      granted_at: nil,
      granted_token: nil
    )
    request_token
  end

  def cancel_request_for(user)
    account_reset_request = AccountResetRequest.find_by(user_id: user.id)
    account_reset_request.update(cancelled_at: Time.zone.now)
  end

  def grant_request(user)
    AccountReset::GrantRequest.new(user).call
  end
end
