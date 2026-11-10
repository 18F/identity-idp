# frozen_string_literal: true

# Grants account-preserving MFA recovery requests whose waiting period has
# elapsed, and emails each user the single-use recovery link.
#
# Only looks at `waiting` requests in its own table. Legacy
# `AccountResetRequest` rows are never read or modified.
class GrantAccountRecoveryRequestsAndSendEmailsJob < ApplicationJob
  queue_as :long_running

  def perform(now)
    notifications_sent = 0

    requests_past_waiting_period(now).each do |account_recovery_request|
      notifications_sent += 1 if grant_request_and_send_email(account_recovery_request)
    end

    analytics.account_recovery_notifications(count: notifications_sent)

    notifications_sent
  end

  private

  def requests_past_waiting_period(now)
    AccountRecoveryRequest
      .where(state: AccountRecoveryRequest::WAITING)
      .where(requested_at: ...(now - IdentityConfig.store.account_recovery_wait_period_days.days))
      .order(requested_at: :asc)
  end

  def grant_request_and_send_email(account_recovery_request)
    email_address = account_recovery_request.user.last_sign_in_email_address

    # Without a deliverable address the link could never reach the user, so
    # fail closed rather than burning the request on an email nobody receives.
    if email_address.blank?
      analytics.account_recovery_granted(success: false, failure_reason: 'no_email_address')
      return false
    end

    result = AccountRecovery::GrantRequest.new(
      account_recovery_request: account_recovery_request,
    ).call

    if !result.success?
      analytics.account_recovery_granted(
        success: false,
        failure_reason: result.failure_reason.to_s,
      )
      return false
    end

    send_granted_email(account_recovery_request.user, email_address, result)

    analytics.account_recovery_granted(success: true)

    true
  end

  def send_granted_email(user, email_address, result)
    # deliver_now, not deliver_now_or_later: this already runs in a background
    # worker, and deliver_later would serialize the raw tokens into the
    # good_jobs table in plaintext, defeating the point of storing only
    # fingerprints.
    # rubocop:disable IdentityIdp/MailLaterLinter
    UserMailer.with(user: user, email_address: email_address)
      .account_recovery_granted(
        token: result.token.raw,
      ).deliver_now
    # rubocop:enable IdentityIdp/MailLaterLinter
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
