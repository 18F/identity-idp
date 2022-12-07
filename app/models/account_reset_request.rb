class AccountResetRequest < ApplicationRecord
  self.ignored_columns = %w[reported_fraud_at]

  belongs_to :user

  def granted_token_valid?
    granted_token.present? && !granted_token_expired?
  end

  def granted_token_expired?
    granted_at.present? &&
      ((Time.zone.now - granted_at) >
       IdentityConfig.store.account_reset_token_valid_for_days.days)
  end
end

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: account_reset_requests
#
#  id            :bigint           not null, primary key
#  cancelled_at  :datetime
#  granted_at    :datetime
#  granted_token :string
#  request_token :string
#  requested_at  :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :integer          not null
#
# Indexes
#
#  index_account_reset_requests_on_granted_token  (granted_token) UNIQUE
#  index_account_reset_requests_on_request_token  (request_token) UNIQUE
#  index_account_reset_requests_on_timestamps     (cancelled_at,granted_at,requested_at)
#  index_account_reset_requests_on_user_id        (user_id) UNIQUE
#
# rubocop:enable Layout/LineLength
