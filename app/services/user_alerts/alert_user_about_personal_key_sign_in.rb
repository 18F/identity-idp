module UserAlerts
  class AlertUserAboutPersonalKeySignIn
    def self.call(user, disavowal_token)
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.personal_key_sign_in(
          email_address.email, disavowal_token: disavowal_token
        ).deliver_now
      end
      MfaContext.new(user).phone_configurations.each do |phone_configuration|
        Telephony.send_personal_key_sign_in_notice(to: phone_configuration.phone)
      end
    end
  end
end
