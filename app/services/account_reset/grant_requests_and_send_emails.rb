module AccountReset
  class GrantRequestsAndSendEmails < ApplicationJob
    queue_as :low

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      enqueue_limit: 1,
      perform_limit: 1,
      key: -> do
        now = arguments.first
        five_minutes = 5.minutes.to_i
        rounded = (now.to_i / five_minutes) * five_minutes

        "grant-requests-and-send-emails-#{rounded}"
      end,
    )

    discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError

    def perform(_now)
      notifications_sent = 0
      AccountResetRequest.where(
        sql_query_for_users_eligible_to_delete_their_accounts,
        tvalue: Time.zone.now - IdentityConfig.store.account_reset_wait_period_days.days,
      ).order('requested_at ASC').each do |arr|
        notifications_sent += 1 if grant_request_and_send_email(arr)
      end

      analytics.track_event(
        Analytics::ACCOUNT_RESET,
        event: :notifications,
        count: notifications_sent
      )

      notifications_sent
    end

    private

    def analytics
      @analytics ||= Analytics.new(
        user: AnonymousUser.new,
        request: nil,
        sp: nil,
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
        UserMailer.account_reset_granted(user, email_address, arr).deliver_now
      end
      true
    end
  end
end
