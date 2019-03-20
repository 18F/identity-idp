module DeviceTracking
  class AlertUserAboutNewDevice
    def self.call(user, device)
      send_emails(user, device)
      send_sms_messages(user)
    end

    def self.send_emails(user, device)
      login_location = DeviceDecorator.new(device).last_sign_in_location_and_ip
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.new_device_sign_in(
          email_address,
          device.last_used_at.strftime('%B %-d, %Y %H:%M'),
          login_location,
        ).deliver_now
      end
    end
    private_class_method :send_emails

    def self.send_sms_messages(user)
      return unless FeatureManagement.send_new_device_sms?
      user.phone_configurations.each do |phone_configuration|
        SmsNewDeviceSignInNotifierJob.perform_now(phone: phone_configuration.phone)
      end
    end
    private_class_method :send_sms_messages
  end
end
