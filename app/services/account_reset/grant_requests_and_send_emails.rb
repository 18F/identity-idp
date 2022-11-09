module AccountReset
  class GrantRequestsAndSendEmails < ApplicationJob
    queue_as :low

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> do
        rounded = TimeService.round_time(time: arguments.first, interval: 5.minutes)
        "grant-requests-and-send-emails-#{rounded.to_i}"
      end,
    )

    discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError

    def perform(now)
      notifications_sent = 0
      AccountResetRequest.where(
        sql_query_for_users_eligible_to_delete_their_accounts,
        tvalue: now - IdentityConfig.store.account_reset_wait_period_days.days,
      ).order('requested_at ASC').each do |arr|
        notifications_sent += 1 if grant_request_and_send_email(arr)
      end

      analytics.account_reset_notifications(count: notifications_sent)

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

    def sql_query_for_users_eligible_to_delete_their_accounts
      <<~SQL
        cancelled_at IS NULL AND
        granted_at IS NULL AND
        requested_at < :tvalue AND
        request_token IS NOT NULL AND
        granted_token IS NULL
      SQL
    end

    def grant_request_and_send_email(arr)
      user = arr.user
      return false unless AccountReset::GrantRequest.new(user).call

      arr = arr.reload
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: user, email_address: email_address).
          account_reset_granted(arr).deliver_now_or_later
      end
      true
    end
  end
end
