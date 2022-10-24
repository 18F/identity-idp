module UserAlerts
  class AlertUserAboutAccountVerified
    def self.call(user:, date_time:, sp_name:, disavowal_token:)
      sp_name ||= APP_NAME
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: user, email_address: email_address).account_verified(
          date_time: date_time,
          sp_name: sp_name,
          disavowal_token: disavowal_token,
        ).deliver_now_or_later
      end
    end
  end
end
