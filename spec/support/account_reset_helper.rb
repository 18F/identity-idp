module AccountResetHelper
  def create_account_reset_request_for(user)
    AccountResetService.new(user).create_request
    account_reset_request = AccountResetRequest.find_by(user_id: user.id)
    account_reset_request.request_token
  end

  def cancel_request_for(user)
    account_reset_request = AccountResetRequest.find_by(user_id: user.id)
    account_reset_request.update(cancelled_at: Time.zone.now)
  end
end
