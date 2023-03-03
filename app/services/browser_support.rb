class BrowserSupport
  @cache = LruRedux::Cache.new(1_000)

  BROWSERSLIST_TO_BROWSER_MAP = {
    and_chr: :chrome?,
    and_uc: :uc_browser?,
    chrome: :chrome?,
    edge: :edge?,
    firefox: :firefox?,
    ios_saf: :safari?,
    op_mini: :opera_mini?,
    opera: :opera?,
    safari: :safari?,
    samsung: :samsung_browser?,
  }.transform_values { |method| Browser::Base.instance_method(method) }.
    with_indifferent_access.
    freeze

  class << self
    attr_reader :cache

    def supported?(user_agent)
      return false if user_agent.nil?
      return true if browser_support_config.nil?

      cache.getset(user_agent) do
        matchers.any? { |matcher| matcher.call(BrowserCache.parse(user_agent)) }
      end
    end

    private

    def matchers
      @matchers ||= browser_support_config.flat_map do |config_entry|
        key, version = config_entry.split(' ', 2)
        browser_matcher = BROWSERSLIST_TO_BROWSER_MAP[key]
        next [] if !browser_matcher

        low_version, = version.split('-', 2)
        low_version = nil if !numeric?(low_version)
        Proc.new do |browser|
          browser_matcher.bind_call(browser, low_version && ">= #{low_version}")
        end
      end
    end

    def numeric?(value)
      Float(value)
      true
    rescue ArgumentError
      false
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
