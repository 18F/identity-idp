# frozen_string_literal: true

module UserAlerts
  class AlertUserAboutNewDevice
    def self.call(event:, device:, disavowal_token:)
      return if IdentityConfig.store.feature_new_device_alert_aggregation_enabled
      device_decorator = DeviceDecorator.new(device)
      login_location = device_decorator.last_sign_in_location_and_ip
      device_name = device_decorator.nice_name

      event.user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: event.user, email_address: email_address).new_device_sign_in(
          date: device.last_used_at.in_time_zone('Eastern Time (US & Canada)').
            strftime('%B %-d, %Y %H:%M Eastern Time'),
          location: login_location,
          device_name: device_name,
          disavowal_token: disavowal_token,
        ).deliver_now_or_later
      end
    end

    def self.schedule_alert(event:)
      return if !IdentityConfig.store.feature_new_device_alert_aggregation_enabled ||
                event.user.sign_in_new_device_at.present?
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

      user.update(sign_in_new_device_at: nil)
      true
    end

    def self.sign_in_events_start_time(user:)
      # Avoid scenarios where stale events may be reflected in the time since sign in:
      #
      # 1. The feature is enabled for a short time in a deployed environment before being disabled
      # 2. In local development, the server is not always active and the job may not run until later
      #
      # Typically, it's guaranteed that even in the worst-case of a sign-in occurring immediately
      # after a scheduled job run, it should take no longer than twice the scheduled delay. A small
      # buffer is added to account for delays of the job run or within the job itself.
      [
        user.sign_in_new_device_at,
        (IdentityConfig.store.new_device_alert_delay_in_minutes * 3).minutes.ago,
      ].max
    end
  end
end
