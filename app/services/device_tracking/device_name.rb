module DeviceTracking
  class DeviceName
    def self.call(device)
      device_user_agent = device.user_agent
      parsed_browser = BrowserCache.parse(device_user_agent)
      I18n.t(
        'account.index.device',
        browser: browser(parsed_browser),
        os: os(parsed_browser),
      )
    end

    def self.browser(browser)
      "#{browser.name} #{browser.version}"
    end
    private_class_method :browser

    def self.os(browser)
      major_version = browser.platform.version.split('.').first
      "#{browser.platform.name} #{major_version}"
    end
    private_class_method :os
  end
end
