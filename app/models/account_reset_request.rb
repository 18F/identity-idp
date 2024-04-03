# frozen_string_literal: true

class AccountResetRequest < ApplicationRecord
  self.ignored_columns = %w[reported_fraud_at]

  belongs_to :user
  # rubocop:disable Rails/InverseOf
  belongs_to :requesting_service_provider,
             class_name: 'ServiceProvider',
             foreign_key: 'requesting_issuer',
             primary_key: 'issuer'
  # rubocop:enable Rails/InverseOf

  def granted_token_valid?
    granted_token.present? && !granted_token_expired?
  end

  def granted_token_expired?
    granted_at.present? &&
      ((Time.zone.now - granted_at) >
       IdentityConfig.store.account_reset_token_valid_for_days.days)
  end
end
