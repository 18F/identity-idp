module DeviceTracking
  class ListDeviceEvents
    def self.call(user, device_id)
      return [] unless Device.where(user_id: user.id, device_id: device_id)
      Event.where(device_id: device_id).order(created_at: :desc)
    end
  end
end
