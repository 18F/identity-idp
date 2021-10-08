module DeviceTracking
  class DeviceName
    def self.call(device)
      browser = BrowserCache.parse(device.user_agent)
      I18n.t(
        'account.index.device',
        browser: "#{browser.name} #{browser.version}",
        os: "#{browser.platform.name} #{browser.platform.version.split('.').first}",
      )
    end
  end
end
