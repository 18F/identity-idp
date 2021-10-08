module DeviceTracking
  class ListDevices
    def self.call(user_id, offset, limit)
      devices = Device.where(user_id: user_id).order(last_used_at: :desc).offset(offset).
                limit(limit)
      devices.each { |device| device.nice_name = DeviceName.call(device) }
    end
  end
end
