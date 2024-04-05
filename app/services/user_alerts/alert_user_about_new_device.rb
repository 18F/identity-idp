# frozen_string_literal: true

module UserAlerts
  class AlertUserAboutNewDevice
    def self.call(event:)
      if IdentityConfig.store.feature_new_device_alert_aggregation_enabled
        event.user.sign_in_new_device_at ||= event.created_at
        event.user.save
      else
        device_decorator = DeviceDecorator.new(event.device)
        login_location = device_decorator.last_sign_in_location_and_ip
        device_name = device_decorator.nice_name

        event.user.confirmed_email_addresses.each do |email_address|
          UserMailer.with(user: event.user, email_address: email_address).new_device_sign_in(
            date: device.last_used_at.in_time_zone('Eastern Time (US & Canada)').
              strftime('%B %-d, %Y %H:%M Eastern Time'),
            location: login_location,
            device_name: device_name,
            disavowal_token: event.disavowal_token,
          ).deliver_now_or_later
        end
      end
    end

    def self.send_alert(user)
      return false unless user.sign_in_new_device_at

      events = user.events.where(
        created_at: user.sign_in_new_device_at..,
        event_type: [
          'sign_in_before_2fa',
          'sign_in_unsuccessful_2fa',
          'sign_in_after_2fa',
        ],
      ).order(:created_at)

      disavowal_event = events.reverse_each.find(&:disavowal_token_fingerprint)
      return false unless disavowal_event
      disavowal_token = disavowal_event.disavowal_token_fingerprint

      user.confirmed_email_addresses.each do |email_address|
        mailer = UserMailer.with(user:, email_address:)
        mail = case disavowal_event.event_type
        when 'sign_in_before_2fa'
          mailer.new_device_sign_in_before_2fa(events:, disavowal_token:)
        when 'sign_in_after_2fa'
          mailer.new_device_sign_in_after_2fa(events:, disavowal_token:)
        end
        mail.deliver_now_or_later
      end

      user.update(sign_in_new_device_at: nil)
      true
    end
  end
end
