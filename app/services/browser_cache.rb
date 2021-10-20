class BrowserCache
  @cache = LruRedux::Cache.new(1_000)

  # @param [String] user_agent
  # @return [Browser]
  def self.parse(user_agent)
    @cache.getset(user_agent) { Browser.new(user_agent) }
  end

  # Should probably only be used in tests
  def self.clear
    @cache.clear
  end
end
