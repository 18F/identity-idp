class BrowserCache
  @cache = LruRedux::Cache.new(1_000)

  # Detects browser attributes from User-Agent, truncated to 2047 bytes due
  # to: https://github.com/fnando/browser/blob/fa4f685482c315b8/lib/browser/browser.rb#L64-L65
  # @param [String] user_agent
  # @return [Browser]
  def self.parse(user_agent)
    return Browser.new("") if user_agent.nil?

    @cache.getset(user_agent) do
      Browser.new(user_agent.mb_chars.limit(Browser.user_agent_size_limit - 1).to_s)
    end
  end

  # Should probably only be used in tests
  def self.clear
    @cache.clear
  end

  def self.cache
    @cache
  end
end
