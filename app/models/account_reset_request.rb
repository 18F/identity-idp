class AccountResetRequest < ApplicationRecord
  self.ignored_columns = %w[reported_fraud_at]

  belongs_to :user

  def granted_token_valid?
    granted_token.present? && !granted_token_expired?
  end

  def granted_token_expired?
    granted_at.present? &&
      ((Time.zone.now - granted_at) > Figaro.env.account_reset_token_valid_for_days.to_i.days)
  end
end
