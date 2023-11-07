class BrowserSupport
  @cache = LruRedux::Cache.new(1_000)

  # rubocop:disable Layout/LineLength
  BROWSERSLIST_TO_BROWSER_MAP = {
    and_chr: ->(browser, version) { browser.android? && !browser.platform.android_webview? && browser.chrome?(version) },
    and_uc: ->(browser, version) { browser.android? && browser.uc_browser?(version) },
    android: ->(browser, version) { browser.platform.android_webview? && browser.send(:detect_version?, browser.version, version) },
    chrome: ->(browser, version) { !browser.platform.android_webview? && browser.chrome?(version) },
    edge: ->(browser, version) { browser.edge?(version) },
    firefox: ->(browser, version) { browser.firefox?(version) },
    ios_saf: ->(browser, version) { browser.ios? && browser.safari?(version) },
    op_mini: ->(browser, version) { browser.opera_mini?(version) },
    opera: ->(browser, version) { browser.opera?(version) },
    safari: ->(browser, version) { browser.safari?(version) },
    samsung: ->(browser, version) { browser.samsung_browser?(version) },
  }.with_indifferent_access.freeze
  # rubocop:enable Layout/LineLength

  class << self
    def supported?(user_agent)
      return false if user_agent.nil?
      return true if browser_support_config.nil?

      cache.getset(user_agent) do
        matchers.any? { |matcher| matcher.call(BrowserCache.parse(user_agent)) }
      end
    end

    def clear_cache!
      cache.clear
      @matchers = nil
      remove_instance_variable(:@browser_support_config) if defined?(@browser_support_config)
    end

    private

    attr_reader :cache

    def matchers
      @matchers ||= browser_support_config.flat_map do |config_entry|
        key, version = config_entry.split(' ', 2)
        browser_matcher = BROWSERSLIST_TO_BROWSER_MAP[key]
        next [] if !browser_matcher

        low_version, _high_version = version.split('-', 2)
        low_version = nil if !numeric?(low_version)
        proc { |browser| browser_matcher.call(browser, low_version && ">= #{low_version}") }
      end
    end

    def numeric?(value)
      Float(value)
      true
    rescue ArgumentError
      false
    end

    def browser_support_config
      return @browser_support_config if defined?(@browser_support_config)
      @browser_support_config = begin
        JSON.parse(File.read(Rails.root.join('browsers.json')))
      rescue JSON::ParserError, Errno::ENOENT
        nil
      end
    end
  end
end
