module DeviceTracking
  class CreateDevice
    def self.call(user, request)
      Device.create(user_id: user.id,
                    user_agent: request.user_agent || '',
                    cookie_uuid: SecureRandom.uuid,
                    last_used_at: Time.zone.now,
                    last_ip: request.remote_ip)
    end
  end
end
