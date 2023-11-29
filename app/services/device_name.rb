class DeviceName

  def self.from_user_agent(user_agent)
    browser = BrowserCache.parse(user_agent)
    os = browser.platform.name
    os_version = browser.platform.version&.split('.')&.first
    os = "#{os} #{os_version}" if os_version

    I18n.t(
      'account.index.device',
      browser: "#{browser.name} #{browser.version}",
      os: os,
    )
  end
end