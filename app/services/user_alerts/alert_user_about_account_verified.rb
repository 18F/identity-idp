module UserAlerts
  class AlertUserAboutAccountVerified
    def self.call(user:, date_time:, sp_name:, disavowal_token:)
      sp_name ||= APP_NAME
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.account_verified(
          user,
          email_address,
          date_time: date_time,
          sp_name: sp_name,
          disavowal_token: disavowal_token,
        ).deliver_now
      end
    end
  end
end
