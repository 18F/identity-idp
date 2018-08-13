class AccountResetService
  def initialize(user)
    @user_id = user.id
  end

  def create_request
    account_reset = account_reset_request
    account_reset.update(request_token: SecureRandom.uuid,
                         requested_at: Time.zone.now,
                         cancelled_at: nil,
                         granted_at: nil,
                         granted_token: nil)
  end

  def self.report_fraud(token)
    account_reset = token.blank? ? nil : AccountResetRequest.find_by(request_token: token)
    return false unless account_reset
    now = Time.zone.now
    account_reset.update(cancelled_at: now,
                         reported_fraud_at: now,
                         request_token: nil,
                         granted_token: nil)
  end

  def grant_request
    token = SecureRandom.uuid
    arr = AccountResetRequest.find_by(user_id: @user_id)
    arr.with_lock do
      return false if arr.granted_token_valid?
      account_reset_request.update(granted_at: Time.zone.now,
                                   granted_token: token)
    end
    true
  end

  def self.grant_tokens_and_send_notifications
    users_sql = <<~SQL
      cancelled_at IS NULL AND
      granted_at IS NULL AND
      requested_at < :tvalue AND
      request_token IS NOT NULL AND
      granted_token IS NULL
    SQL
    send_notifications_with_sql(users_sql)
  end

  def self.send_notifications_with_sql(users_sql)
    notifications_sent = 0
    AccountResetRequest.where(
      users_sql, tvalue: Time.zone.now - Figaro.env.account_reset_wait_period_days.to_i.days
    ).order('requested_at ASC').each do |arr|
      notifications_sent += 1 if reset_and_notify(arr)
    end
    notifications_sent
  end
  private_class_method :send_notifications_with_sql

  def self.reset_and_notify(arr)
    user = arr.user
    return false unless AccountResetService.new(user).grant_request
    UserMailer.account_reset_granted(user, arr.reload).deliver_later
    true
  end
  private_class_method :reset_and_notify

  private

  def account_reset_request
    AccountResetRequest.find_or_create_by(user_id: @user_id)
  end
end
