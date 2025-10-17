# frozen_string_literal: true

module UserAlerts
  class AlertUserAboutMaxAttempts
    def self.max_attempts_alert(user:, disavowal_token:)
      events = user.events.where(
        created_at: user.sign_in_new_device_at..,
        event_type: [
          'sign_in_before_2fa',
          'sign_in_unsuccessful_2fa',
        ],
      ).order(:created_at).includes(:device).to_a

      user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user:, email_address:)
          .new_device_sign_in_before_2fa(events:, disavowal_token:).deliver_now_or_later
      end
    end
  end
end
