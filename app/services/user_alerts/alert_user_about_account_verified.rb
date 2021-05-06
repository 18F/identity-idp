module UserAlerts
  class AlertUserAboutAccountVerified
    def self.call(user, date_time, app, disavowal_token)
      app = app || 'Login.gov'
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.account_verified(
          user,
          email_address,
          date_time: date_time,
          app: app,
          disavowal_token: disavowal_token,
        ).deliver_now
      end
    end
  end
end
