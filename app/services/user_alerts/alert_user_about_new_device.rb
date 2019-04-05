module UserAlerts
  class AlertUserAboutNewDevice
    def self.call(user, device, disavowal_token)
      send_emails(user, device, disavowal_token)
      send_sms_messages(user)
    end

    def self.send_emails(user, device, disavowal_token)
      login_location = DeviceDecorator.new(device).last_sign_in_location_and_ip
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.new_device_sign_in(
          email_address,
          device.last_used_at.in_time_zone('EST').strftime('%B %-d, %Y %H:%M Eastern Time'),
          login_location,
          disavowal_token,
        ).deliver_now
      end
    end
    private_class_method :send_emails

    def self.send_sms_messages(user)
      return unless FeatureManagement.send_new_device_sms?
      MfaContext.new(user).phone_configurations.each do |phone_configuration|
        SmsNewDeviceSignInNotifierJob.perform_now(phone: phone_configuration.phone)
      end
    end
    private_class_method :send_sms_messages
  end
end
