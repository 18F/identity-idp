module DeviceTracking
  class ManageDevice
    # primary method: updates the usage time if it is not a new device, and calls create
    # if the device used to log in has not been used before and alerts the user via email
    # and sms about the new device in use
    def self.call(user, device_hash, remote_ip, user_agent)
      user_id = user.id

      device = DeviceTracking::LookupDeviceForUser.call(user_id, device_hash)
      alert_user = device.nil? && UserDecorator.new(user).devices?

      device = if device
                 DeviceTracking::UpdateDevice.call(device, remote_ip)
               else
                 DeviceTracking::CreateDevice.call(user_id, remote_ip, user_agent, device_hash)
               end

      alert_user_of_new_device(user, device) if alert_user

      device
    end

    # private
    def self.alert_user_of_new_device(user, device)
      login_location = DeviceDecorator.new(device).last_sign_in_location_and_ip
      UserMailer.new_device_sign_in(user.email,
                                    Time.zone.now.strftime('%B %-d, %Y %H:%M'),
                                    login_location).deliver_now

      SmsNewDeviceSignInNotifierJob.perform_now(phone: MfaContext.new(user).phone_configurations.first&.phone)
    end
    private_class_method :alert_user_of_new_device
  end
end
