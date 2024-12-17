# frozen_string_literal: true

module AccountReset
  class PendingRequestForUser
    include AccountResetConcern
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def get_account_reset_request
      AccountResetRequest.where(
        user: user,
        granted_at: nil,
        cancelled_at: nil,
      ).where(
        'requested_at > ?',
        account_reset_wait_period_days(user).ago,
      ).order(requested_at: :asc).first
    end

    def cancel_account_reset_request!(account_reset_request_id:, cancelled_at:)
      # rubocop:disable Rails/SkipsModelValidations
      result = AccountResetRequest.where(
        id: account_reset_request_id,
        user: user,
        granted_at: nil,
        cancelled_at: nil,
      ).where(
        'requested_at > ?',
        account_reset_wait_period_days(user).ago,
      ).update_all(cancelled_at: cancelled_at, updated_at: Time.zone.now)
      # rubocop:enable Rails/SkipsModelValidations

      notify_user! if result == 1
    end

    def notify_user!
      notify_user_via_email_of_account_reset_cancellation
      notify_user_via_phone_of_account_reset_cancellation
    end

    private

    def notify_user_via_email_of_account_reset_cancellation
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: user, email_address: email_address).account_reset_cancel
          .deliver_now_or_later
      end
    end

    def notify_user_via_phone_of_account_reset_cancellation
      MfaContext.new(user).phone_configurations.each do |phone_configuration|
        phone = phone_configuration.phone
        Telephony.send_account_reset_cancellation_notice(
          to: phone,
          country_code: Phonelib.parse(phone).country,
        )
      end
    end
  end
end
