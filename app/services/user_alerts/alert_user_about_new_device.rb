module UserAlerts
  class AlertUserAboutNewDevice
    def self.call(user, device, disavowal_token)
      login_location = DeviceDecorator.new(device).last_sign_in_location_and_ip
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: user, email_address: email_address).new_device_sign_in(
          date: device.last_used_at.in_time_zone('Eastern Time (US & Canada)').
            strftime('%B %-d, %Y %H:%M Eastern Time'),
          location: login_location,
          disavowal_token: disavowal_token,
        ).deliver_now_or_later
      end
    end
  end
end
