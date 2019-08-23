module UserAlerts
  class AlertUserAboutNewDevice
    def self.call(user, device, disavowal_token)
      login_location = DeviceDecorator.new(device).last_sign_in_location_and_ip
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.new_device_sign_in(
          email_address,
          device.last_used_at.in_time_zone('Eastern Time (US & Canada)').
            strftime('%B %-d, %Y %H:%M Eastern Time'),
          login_location,
          disavowal_token,
        ).deliver_now
      end
    end
  end
end
