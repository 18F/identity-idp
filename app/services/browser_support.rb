class BrowserSupport
  def self.supported?(user_agent)
    matcher = BrowserslistUseragent::Match.new(browser_support_config, user_agent)
    matcher.browser? && matcher.version?(allow_higher: true)
  end

  def self.browser_support_config
    @browser_support_config ||= JSON.parse(File.read(Rails.root.join('browsers.json')))
  end
end
