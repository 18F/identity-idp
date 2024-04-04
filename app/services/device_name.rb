# frozen_string_literal: true

class DeviceName
  def self.from_user_agent(user_agent)
    browser = BrowserCache.parse(user_agent)
    I18n.t(
      'account.index.device',
      browser: "#{browser.name} #{browser.version}",
      os: browser.platform.name,
    )
  end
end
