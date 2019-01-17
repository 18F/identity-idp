module DeviceTracking
  class ListDevices
    def call(user)
      devices = Device.where(user_id: user.id).order(created_at: :desc)
      # heavy cost to load; instantiate once and parse in bulk
      parser = UserAgentParser::Parser.new
      devices.each { |device| device.nice_name = nice_name(parser, device) }
    end

    private

    def nice_name(parser, device)
      device_user_agent = device.user_agent
      user_agent = parser.parse(device_user_agent)
      if user_agent
        I18n.t('account.index.device',
               browser: browser(user_agent),
               os: os(user_agent))
      else
        device_user_agent
      end
    end

    def browser(user_agent)
      version = user_agent.version
      "#{user_agent.family} #{version ? version.major : ''}"
    end

    def os(user_agent)
      user_agent_os = user_agent.os
      version = user_agent_os.version
      "#{user_agent_os.family} #{version ? version.major : ''}"
    end
  end
end
