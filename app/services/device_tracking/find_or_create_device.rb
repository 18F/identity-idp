module DeviceTracking
  class FindOrCreateDevice
    # :reek:DuplicateMethodCall
    def self.call(user, hash, remote_ip, user_agent)
      user_has_multiple_devices = UserDecorator.new(user).devices?
      device = LookupDeviceForUser.call(user.id, hash)

      if device
        UpdateDevice.call(device, remote_ip)
      else
        new_device = CreateDevice.call(user.id, remote_ip, user_agent, hash)
        AlertUserAboutNewDevice.call(user, new_device) if user_has_multiple_devices
        new_device
      end
    end
  end
end
