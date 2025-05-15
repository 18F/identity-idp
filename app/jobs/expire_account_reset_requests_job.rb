# frozen_string_literal: true

class ExpireAccountResetRequestsJob < ApplicationJob
  queue_as :long_running

  def perform(now)
    notifications_sent = 0
    expired_days = (
      IdentityConfig.store.account_reset_wait_period_days +
      IdentityConfig.store.account_reset_token_valid_for_days
    ).days
    AccountResetRequest.where(
      sql_query_for_users_with_expired_requests,
      tvalue: now - expired_days,
    ).order('requested_at ASC').each do |arr|
      notifications_sent += 1 if expire_request(arr)
    end

    analytics.account_reset_request_expired

    notifications_sent
  end

  private

  def analytics
    @analytics ||= Analytics.new(
      user: AnonymousUser.new,
      request: nil,
      sp: nil,
      session: {},
    )
  end

  def sql_query_for_users_with_expired_requests
    <<~SQL
      cancelled_at IS NULL AND
      granted_at < :tvalue
    SQL
  end

  def expire_request(arr)
    arr.update(cancelled_at: Time.zone.now)
    arr.save
  end
end
