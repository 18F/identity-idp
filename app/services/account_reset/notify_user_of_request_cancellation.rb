module AccountReset
  class NotifyUserOfRequestCancellation
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def call
      notify_user_via_email_of_account_reset_cancellation
      notify_user_via_phone_of_account_reset_cancellation
    end

    private

    def notify_user_via_email_of_account_reset_cancellation
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: user, email_address: email_address).account_reset_cancel.
          deliver_now_or_later
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
