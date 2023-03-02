class BrowserSupport
  @cache = LruRedux::Cache.new(1_000)

  class << self
    attr_reader :cache

    def supported?(user_agent)
      return false if user_agent.nil?
      return true if browser_support_config.nil?

      cache.getset(user_agent) { matcher_supported_version?(user_agent) }
    end

    private

    def matcher_supported_version?(user_agent)
      matcher.instance_variable_set(:@user_agent_string, user_agent)
      matcher.version?(allow_higher: true)
    end

    def matcher
      @matcher ||= BrowserslistUseragent::Match.new(browser_support_config, nil)
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
