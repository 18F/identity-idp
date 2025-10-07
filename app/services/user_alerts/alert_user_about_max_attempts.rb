# frozen_string_literal: true

module UserAlerts
  class AlertUserAboutMaxAttempts
    def self.call(user:, disavowal_token:)
      user.confirmed_email_addresses.each do |email_address|
        mailer = UserMailer.with(user:, email_address:)
        mailer.with(user: user, email_address: email_address)
          .new_device_sign_in_before_2fa(events:, disavowal_token:)
      end
    end
  end
end
