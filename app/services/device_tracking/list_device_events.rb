module DeviceTracking
  class ListDeviceEvents
    def self.call(user_id, device_id, offset, limit)
      return [] unless Device.where(user_id: user_id, device_id: device_id)
      Event.where(user_id: user_id, device_id: device_id).offset(offset).limit(limit).
        order(created_at: :desc)
    end
  end
end
