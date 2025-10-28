# frozen_string_literal: true

module UserAlerts
  class AlertUserAboutMaxAttempts
    def self.max_attempts_alert(user:, disavowal_token:)
      events = user.events.where(
        created_at: sign_in_events_window(user:)..,
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

    # Makes it so that we only list events from 5 minutes ago
    def self.sign_in_events_window(user:)
      [
        user.created_at,
        IdentityConfig.store.new_device_alert_delay_in_minutes.minutes.ago,
      ].max
    end
  end
end
