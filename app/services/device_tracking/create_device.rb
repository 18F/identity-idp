module DeviceTracking
  class CreateDevice
    def self.call(user, request, current_cookie_uuid)
      Device.create(user_id: user.id,
                    user_agent: request.user_agent || '',
                    cookie_uuid: current_cookie_uuid.presence || SecureRandom.uuid,
                    last_used_at: Time.zone.now,
                    last_ip: request.remote_ip)
    end
  end
end
