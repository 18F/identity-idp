module DeviceTracking
  class ListDevices
    def call(user)
      devices = Device.where(user_id: user.id).order(created_at: :desc)
      # heavy cost to load; instantiate once and parse in bulk
      parser = UserAgentParser::Parser.new
      devices.each do |device|
        user_agent = parser.parse(device.user_agent)
        device.nice_name = I18n.t('account.index.device',
                                  browser: browser(user_agent),
                                  os: os(user_agent))
      end
      devices
    end

    private

    def browser(user_agent)
      "#{user_agent.family} #{user_agent.version.major}"
    end

    def os(user_agent)
      user_agent_os = user_agent.os
      "#{user_agent_os.family} #{user_agent_os.version.major}"
    end
  end
end
