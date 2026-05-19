# frozen_string_literal: true

module UserAlerts
  class AlertUserAboutNewDevice
    def self.schedule_alert(event:)
      return if event.user.sign_in_new_device_at.present?
      event.user.update(sign_in_new_device_at: event.created_at)
    end

    def self.send_alert(user:, disavowal_event:, disavowal_token:)
      return false unless user.sign_in_new_device_at

      events = user.events.where(
        created_at: sign_in_events_start_time(user:)..,
        event_type: [
          'sign_in_before_2fa',
          'sign_in_unsuccessful_2fa',
          'sign_in_after_2fa',
        ],
      ).order(:created_at).includes(:device).to_a

      if !events.empty?
        send_email(user, events, disavowal_event, disavowal_token)
      else
        analytics(user).new_device_alert_skipped
      end

      user.update(sign_in_new_device_at: nil)
      true
    end

    def self.sign_in_events_start_time(user:)
      window_start_in_minutes = IdentityConfig.store.new_device_alert_window_start_in_minutes
      start_times = [user.sign_in_new_device_at]
      start_times << window_start_in_minutes.minutes.ago if window_start_in_minutes
      start_times.max
    end

    def self.send_email(user, events, disavowal_event, disavowal_token)
      user.confirmed_email_addresses.each do |email_address|
        mailer = UserMailer.with(user:, email_address:)
        mail = case disavowal_event.event_type
        when 'sign_in_notification_timeframe_expired'
          mailer.new_device_sign_in_before_2fa(events:, disavowal_token:)
        when 'sign_in_after_2fa'
          mailer.new_device_sign_in_after_2fa(events:, disavowal_token:)
        end
        mail.deliver_now_or_later
      end
    end

    def self.analytics(user)
      Analytics.new(user: user, request: nil, session: {}, sp: nil)
    end
  end
end
