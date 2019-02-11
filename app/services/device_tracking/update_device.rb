module DeviceTracking
  class UpdateDevice
    def self.call(device, remote_ip)
      device.last_used_at = Time.zone.now
      device.last_ip = remote_ip
      device.save
      device
    end
  end
end
