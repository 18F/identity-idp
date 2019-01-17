module DeviceTracking
  class UpdateDevice
    def self.call(user, event, request, cookie_uuid)
      device = Device.find_by(user_id: user.id, cookie_uuid: cookie_uuid)
      remote_ip = request.remote_ip
      device.last_used_at = Time.zone.now
      device.last_ip = remote_ip
      device.save
      DeviceEvent.create(device_id: device.id, ip: remote_ip, event_type: event)
    end
  end
end
