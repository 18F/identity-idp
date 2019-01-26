module DeviceTracking
  class ListDevices
    def self.call(user)
      devices = Device.where(user_id: user.id).order(created_at: :desc)
      # heavy cost to load; instantiate once and parse in bulk
      parser = UserAgentParser::Parser.new
      devices.each { |device| device.nice_name = DeviceName.call(parser, device) }
    end
  end
end
