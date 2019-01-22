module DeviceTracking
  class UpdateDevice
    def self.call(device, request)
      device.last_used_at = Time.zone.now
      device.last_ip = request.remote_ip
      device.save
    end
  end
end
