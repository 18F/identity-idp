# frozen_string_literal: true

class BrowserSupport
  @cache = LruRedux::Cache.new(1_000)

  BROWSERSLIST_TO_BROWSER_MAP = {
    and_chr: ->(browser, version) { browser.android? && browser.chrome?(version) },
    and_uc: ->(browser, version) { browser.android? && browser.uc_browser?(version) },
    android: ->(browser, version) { browser.send(:detect_version?, browser.version, version) },
    chrome: ->(browser, version) { browser.chrome?(version) },
    edge: ->(browser, version) { browser.edge?(version) },
    firefox: ->(browser, version) { browser.firefox?(version) },
    ios_saf: ->(browser, version) { browser.ios?(version) },
    op_mini: ->(browser, version) { browser.opera_mini?(version) },
    op_mob: ->(browser, version) { browser.platform.android? && browser.opera?(version) },
    opera: ->(browser, version) { browser.opera?(version) },
    safari: ->(browser, version) { browser.safari?(version) },
    samsung: ->(browser, version) { browser.samsung_browser?(version) },
  }.freeze

  class << self
    def supported?(user_agent)
      return false if user_agent.nil?
      return true if browser_support_config.nil?

      cache.getset(user_agent) do
        browser = BrowserCache.parse(user_agent)
        matchers_for_browser(browser).any? { |_key, matcher| matcher.call(browser) }
      end
    end

    def clear_cache!
      cache.clear
      @matchers = nil
      remove_instance_variable(:@browser_support_config) if defined?(@browser_support_config)
    end

    private

    attr_reader :cache

    def matchers_for_browser(browser)
      if browser.ios?
        matchers.slice(:ios_saf)
      elsif browser.platform.android_webview?
        matchers.slice(:android)
      else
        matchers
      end
    end

    def matchers
      @matchers ||= browser_support_config.each_with_object({}) do |config_entry, result|
        key, version = config_entry.split(' ', 2)
        key = key.to_sym
        browser_matcher = BROWSERSLIST_TO_BROWSER_MAP[key]
        next if !browser_matcher

        low_version, _high_version = version.split('-', 2)
        low_version = nil if !numeric?(low_version)
        version_test = low_version && ">= #{low_version}"
        matcher = proc { |browser| browser_matcher.call(browser, version_test) }
        result[key] = matcher
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
