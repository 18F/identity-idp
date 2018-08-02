class AccountResetRequest < ApplicationRecord
  belongs_to :user

  def self.from_valid_granted_token(granted_token)
    account_reset = AccountResetRequest.find_by(granted_token: granted_token)
    account_reset&.granted_token_valid? ? account_reset : nil
  end

  def granted_token_valid?
    granted_token.present? && !granted_token_expired?
  end

  def granted_token_expired?
    granted_at.present? &&
      ((Time.zone.now - granted_at) > Figaro.env.account_reset_token_valid_for_days.to_i.days)
  end
end
