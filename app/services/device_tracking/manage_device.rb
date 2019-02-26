module DeviceTracking
  class ManageDevice
    # primary method: updates the usage time if it is not a new device, and calls create
    # if the device used to log in has not been used before and alerts the user via email
    # and sms about the new device in use
    # returns the existing, updated device or the new one just created
    # :reek:DuplicateMethodCall

    def self.call(user, hash, remote_ip, user_agent)
      user_has_multiple_devices = UserDecorator.new(user).devices?
      device = DeviceTracking::LookupDeviceForUser.call(user.id, hash)

      if device
        DeviceTracking::UpdateDevice.call(device, remote_ip)
      else
        new_device = DeviceTracking::CreateDevice.call(user.id, remote_ip, user_agent, hash)
        alert_user_of_new_device(user, new_device) if user_has_multiple_devices
        new_device
      end
    end

    def self.alert_user_of_new_device(user, device)
      login_location = DeviceDecorator.new(device).last_sign_in_location_and_ip
      UserMailer.new_device_sign_in(user.email,
                                    device.last_used_at.strftime('%B %-d, %Y %H:%M'),
                                    login_location).deliver_now

      return unless FeatureManagement.send_new_device_sms?

      user.phone_configurations.each do |phone_configuration|
        SmsNewDeviceSignInNotifierJob.perform_now(phone: phone_configuration.phone)
      end
    end
    private_class_method :alert_user_of_new_device
  end
end
