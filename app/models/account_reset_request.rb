# frozen_string_literal: true

class AccountResetRequest < ApplicationRecord
  extend AccountResetConcern # for account_reset_wait_period_days

  belongs_to :user
  # rubocop:disable Rails/InverseOf
  belongs_to :requesting_service_provider,
             class_name: 'ServiceProvider',
             foreign_key: 'requesting_issuer',
             primary_key: 'issuer'
  # rubocop:enable Rails/InverseOf

  # @return [AccountResetRequest, nil]
  def self.pending_request_for(user)
    where(
      user: user,
      granted_at: nil,
      cancelled_at: nil,
    ).where(
      'requested_at > ?',
      account_reset_wait_period_days(user).ago,
    ).order(requested_at: :asc).first
  end

  def cancel!(now: Time.zone.now)
    update(cancelled_at: now)
    AccountReset::NotifyUserOfRequestCancellation.new(user).call
  end

  def granted_token_valid?
    granted_token.present? && !granted_token_expired?
  end

  def granted_token_expired?
    granted_at.present? &&
      ((Time.zone.now - granted_at) >
       IdentityConfig.store.account_reset_token_valid_for_days.days)
  end
end
