# frozen_string_literal: true

module UserAlerts
  class AlertUserAboutAccountVerified
    def self.call(profile:)
      user = profile.user
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: user, email_address: email_address).account_verified(
          date_time: profile.verified_at,
          profile: profile,
        ).deliver_now_or_later
      end
    end
  end
end
