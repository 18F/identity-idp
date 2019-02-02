module DeviceTracking
  class CreateDevice
    COOKIE_LENGTH = 128

    def self.call(user_id, remote_ip, user_agent, uuid)
      Device.create!(user_id: user_id,
                     user_agent: user_agent.to_s,
                     cookie_uuid: uuid.presence || SecureRandom.hex(COOKIE_LENGTH / 2),
                     last_used_at: Time.zone.now,
                     last_ip: remote_ip)
    end
  end
end
