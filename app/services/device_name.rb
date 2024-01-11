class DeviceName
  class << self
    def from_user_agent(user_agent)
      browser = BrowserCache.parse(user_agent)
      os = browser.platform.name
      os_version = browser.platform.version&.split('.')&.first if reliable_os_version?(browser)
      os = "#{os} #{os_version}" if os_version

      I18n.t(
        'account.index.device',
        browser: "#{browser.name} #{browser.version}",
        os: os,
      )
    end

    private

    def reliable_os_version?(browser)
      # Chromium's user agent reduction initiative will produce a unified platform string which may
      # include an inaccurate operation system version.
      # See: https://www.chromium.org/updates/ua-reduction/#unified-format
      #
      # Consider using Browser#chromium_based? if/when it becomes available
      # See: https://github.com/fnando/browser/issues/541
      !browser.chrome? && !browser.edge?
    end
  end
end
