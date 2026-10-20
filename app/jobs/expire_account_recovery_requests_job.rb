# frozen_string_literal: true

# Expires account-preserving MFA recovery requests whose emailed recovery link
# lapsed without being used.
#
# Tokens remain subject to expiry until both the link and password are verified.
class ExpireAccountRecoveryRequestsJob < ApplicationJob
  queue_as :low

  def perform(now)
    expired_count = 0

    requests_with_lapsed_tokens(now).each do |account_recovery_request|
      expired = AccountRecovery::ReconcileRequest.new(
        account_recovery_request: account_recovery_request,
      ).call(now: now)

      expired_count += 1 if expired
    end
    analytics.account_recovery_job_mark_expired(count: expired_count) if expired_count.positive?
    expired_count
  end

  private

  def requests_with_lapsed_tokens(now)
    AccountRecoveryRequest
      .where(state: [AccountRecoveryRequest::GRANTED, AccountRecoveryRequest::LINK_VERIFIED])
      .where(token_expires_at: ..now)
      .order(token_expires_at: :asc)
  end

  def analytics
    @analytics ||= Analytics.new(
      user: AnonymousUser.new,
      request: nil,
      sp: nil,
      session: {},
    )
  end
end
