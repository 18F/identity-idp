module UserAlerts
  class AlertUserAboutAccountRejected
    def self.call(user)
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user:, email_address:).
          account_rejected.
          deliver_now_or_later
      end
    end
  end
end
