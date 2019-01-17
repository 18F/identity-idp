module DeviceTracking
  class CreateDevice
    def self.call(user, event, request)
      last_login_at = Time.zone.now
      uuid = SecureRandom.uuid
      remote_ip = request.remote_ip
      device = Device.create(user_id: user.id,
                             user_agent: request.user_agent || '',
                             cookie_uuid: uuid,
                             last_used_at: last_login_at,
                             last_ip: remote_ip)
      DeviceEvent.create(device_id: device.id, ip: remote_ip, event_type: event)
      uuid
    end
  end
end
