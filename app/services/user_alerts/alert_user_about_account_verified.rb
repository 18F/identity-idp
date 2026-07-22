# frozen_string_literal: true

module UserAlerts
  class AlertUserAboutAccountVerified
    def self.call(profile:, phone: nil)
      user = profile.user
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: user, email_address: email_address).account_verified(
          profile: profile,
        ).deliver_now_or_later
      end

      if profile.enhanced?
        Telephony.send_proofing_completion_confirmation(
          to: phone,
          country_code: Phonelib.parse(phone).country,
          sp_or_app_name: profile.initiating_service_provider&.friendly_name.presence ||
            APP_NAME,
        )
      end
    end
  end
end
