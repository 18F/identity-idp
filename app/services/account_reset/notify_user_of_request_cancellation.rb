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
        UserMailer.account_reset_cancel(user, email_address).deliver_now
      end
    end

    def notify_user_via_phone_of_account_reset_cancellation
      MfaContext.new(user).phone_configurations.each do |phone_configuration|
        Telephony.send_account_reset_cancellation_notice(to: phone_configuration.phone)
      end
    end
  end
end
