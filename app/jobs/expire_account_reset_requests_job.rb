# frozen_string_literal: true

class ExpireAccountResetRequestsJob < ApplicationJob
  queue_as :long_running

  def perform(now)
    puts 'reset job ran'
    resets = 0
    expired_days = (
      IdentityConfig.store.account_reset_token_valid_for_days
    ).days
    AccountResetRequest.where(
      sql_query_for_users_with_expired_requests,
      tvalue: now + expired_days,
    ).order('requested_at ASC').limit(1_000).each do |arr|
      resets += 1 if expire_request(arr)
    end

    analytics.account_reset_request_expired(count: resets)

    resets
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
      request_token IS NOT NULL AND
      cancelled_at IS NULL AND
      granted_at + :tvalue < Time.zone.now
    SQL
  end

  def expire_request(arr)
    arr.update!(
      cancelled_at: Time.zone.now,
      request_token: nil,
      granted_token: nil,
    )
  end
end
