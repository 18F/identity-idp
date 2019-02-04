module DeviceTracking
  class ListDevices
    def self.call(user_id, offset, limit)
      devices = Device.where(user_id: user_id).order(last_used_at: :desc).offset(offset).
                limit(limit)
      # heavy cost to load; instantiate once and parse in bulk
      parser = UserAgentParser::Parser.new
      devices.each { |device| device.nice_name = DeviceName.call(parser, device) }
    end
  end
end
