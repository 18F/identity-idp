module UserAlerts
  class AlertUserAboutPasswordChange
    def self.call(user, disavowal_token)
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: user, email_address: email_address).
          password_changed(disavowal_token: disavowal_token).deliver_now_or_later
      end
    end
  end
end
