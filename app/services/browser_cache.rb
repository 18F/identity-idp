class BrowserCache
  class Result
    def initialize(browser)
      @browser = browser
    end

    def device_mobile?
      return @device_mobile if defined?(@device_mobile)
      @device_mobile = @browser.device.mobile?
    end

    def name
      return @name if defined?(@name)
      @name = @browser.name
    end

    def version
      return @version if defined?(@version)
      @version = @browser.version
    end

    def full_version
      return @full_version if defined?(@full_version)
      @version = @browser.full_version
    end

    def platform_name
      return @platform_name if defined?(@platform_name)
      @platform_name = @browser.platform.name
    end

    def platform_version
      return @platform_version if defined?(@platform_version)
      @platform_version = @browser.platform.version
    end

    def device_name
      return @device_name if defined?(@device_name)
      @device_name = @browser.device.name
    end

    def bot?
      return @bot if defined?(@bot)
      @bot = @browser.bot?
    end

    def ie_11?
      return @ie_11 if defined?(@ie_11)
      @ie_11 = @browser.ie?(11)
    end
  end

  @cache = LruRedux::Cache.new(1_000)
  DEFAULT_RESULT = Result.new(Browser.new(nil))

  # Detects browser attributes from User-Agent, truncated to 2047 bytes due
  # to: https://github.com/fnando/browser/blob/fa4f685482c315b8/lib/browser/browser.rb#L64-L65
  # @param [String] user_agent
  # @return [Browser]
  def self.parse(user_agent)
    return DEFAULT_RESULT if user_agent.nil?

    @cache.getset(user_agent) do
      browser = Browser.new(user_agent.mb_chars.limit(Browser.user_agent_size_limit - 1).to_s)

      Result.new(browser)
    end
  end

  # Should probably only be used in tests
  def self.clear
    @cache.clear
  end
end
