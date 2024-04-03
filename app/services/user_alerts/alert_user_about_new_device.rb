# frozen_string_literal: true

module UserAlerts
  class AlertUserAboutNewDevice
    def self.call(user, device, disavowal_token)
      if IdentityConfig.store.feature_new_device_alert_aggregation
        user.sign_in_new_device_at ||= Time.zone.now
        user.save!
      else
        device_decorator = DeviceDecorator.new(device)
        login_location = device_decorator.last_sign_in_location_and_ip
        device_name = device_decorator.nice_name

        user.confirmed_email_addresses.each do |email_address|
          UserMailer.with(user: user, email_address: email_address).new_device_sign_in(
            date: device.last_used_at.in_time_zone('Eastern Time (US & Canada)').
              strftime('%B %-d, %Y %H:%M Eastern Time'),
            location: login_location,
            device_name: device_name,
            disavowal_token: disavowal_token,
          ).deliver_now_or_later
        end
      end
    end
  end
end
