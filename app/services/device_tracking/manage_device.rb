module DeviceTracking
  class ManageDevice
    # primary method: updates the usage time if it is not a new device, and calls create
    # if the device used to log in has not been used before and alerts the user via email
    # and sms about the new device in use
    # returns the existing, updated device or the new one just created
    def self.call(user, hash, remote_ip, user_agent)
      uid = user.id
      device = DeviceTracking::LookupDeviceForUser.call(uid, hash)

      if device
        DeviceTracking::UpdateDevice.call(device, remote_ip)
      else
        new_device = DeviceTracking::CreateDevice.call(uid, remote_ip, user_agent, hash)
        alert_user_of_new_device(user, new_device) if UserDecorator.new(user).devices?
        new_device
      end
    end

    # private
    def self.alert_user_of_new_device(user, device)
      login_location = DeviceDecorator.new(device).last_sign_in_location_and_ip
      UserMailer.new_device_sign_in(user.email,
                                    Time.zone.now.strftime('%B %-d, %Y %H:%M'),
                                    login_location).deliver_now

      SmsNewDeviceSignInNotifierJob.
        perform_now(phone: MfaContext.new(user).phone_configurations.first&.phone)
    end
    private_class_method :alert_user_of_new_device
  end
end
