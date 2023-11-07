module UserAlerts
  class AlertUserAboutAccountVerified
    def self.call(user:, date_time:, sp_name:)
      sp_name ||= APP_NAME
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user:, email_address:).account_verified(
          date_time:,
          sp_name:,
        ).deliver_now_or_later
      end
    end
  end
end
