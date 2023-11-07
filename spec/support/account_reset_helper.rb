module AccountResetHelper
  def create_account_reset_request_for(user, requesting_issuer = nil)
    request = AccountResetRequest.create_or_find_by(user:)
    request_token = SecureRandom.uuid
    request.update!(
      request_token:,
      requested_at: Time.zone.now,
      cancelled_at: nil,
      granted_at: nil,
      granted_token: nil,
      requesting_issuer:,
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
