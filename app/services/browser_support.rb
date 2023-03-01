class BrowserSupport
  @cache = LruRedux::Cache.new(1_000)

  class << self
    attr_reader :cache

    def supported?(user_agent)
      return false if user_agent.nil?
      return true if browser_support_config.nil?

      @cache.getset(user_agent) do
        matcher = BrowserslistUseragent::Match.new(browser_support_config, user_agent)
        matcher.browser? && matcher.version?(allow_higher: true)
      end
    end

    def browser_support_config
      @browser_support_config = begin
        JSON.parse(File.read(Rails.root.join('browsers.json')))
      rescue JSON::ParserError, Errno::ENOENT
        nil
      end
    end
  end
end
