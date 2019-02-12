module DeviceTracking
  class DeviceName
    def self.call(parser, device)
      device_user_agent = device.user_agent
      user_agent = parser.parse(device_user_agent)
      I18n.t('account.index.device',
             browser: browser(user_agent),
             os: os(user_agent))
    end

    def self.browser(user_agent)
      version = user_agent.version
      "#{user_agent.family} #{version ? version.major : ''}"
    end
    private_class_method :browser

    def self.os(user_agent)
      user_agent_os = user_agent.os
      version = user_agent_os.version
      "#{user_agent_os.family} #{version ? version.major : ''}"
    end
    private_class_method :os
  end
end
