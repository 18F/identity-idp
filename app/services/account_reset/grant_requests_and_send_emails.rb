module AccountReset
  class GrantRequestsAndSendEmails
    def call
      notifications_sent = 0
      AccountResetRequest.where(
        sql_query_for_users_eligible_to_delete_their_accounts,
        tvalue: Time.zone.now - Figaro.env.account_reset_wait_period_days.to_i.days,
      ).order('requested_at ASC').each do |arr|
        notifications_sent += 1 if grant_request_and_send_email(arr)
      end

      # TODO: rewrite analytics so that we can generate events even from
      # background jobs where we have no request or user objects
      # analytics.track_event(Analytics::ACCOUNT_RESET,
      #                       event: :notifications, count: notifications_sent)

      Rails.logger.info("Sent #{notifications_sent} account_reset notifications")

      notifications_sent
    end

    private

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
        UserMailer.account_reset_granted(email_address, arr).deliver_later
      end
      true
    end
  end
end
