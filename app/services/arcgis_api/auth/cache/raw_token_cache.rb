module ArcgisApi::Auth::Cache
  class RawTokenCache
    # @param [Cache::CacheWrapper] cache
    # @param [String] cache_key
    def initialize(cache: nil, cache_key: nil)
      @cache = cache || Cache::CacheWrapper.new
      @cache_key = cache_key || default_api_token_cache_key
    end

    # @return [Object,nil] Cached auth token
    def token
      raw_token = cache.read(cache_key)
      raw_token || nil
    end

    # @param [Object,nil] cache_value the value to write to cache
    # @param [Number] expires_at the hard expiration time in unix time (milliseconds)
    def save_token(cache_value, expires_at)
      cache.write(cache_key, cache_value, expires_at)
    end

    private

    def default_api_token_cache_key
      "#{arcgis_api_token_cache_key_prefix}:#{URI(arcgis_api_generate_token_url).host}"
    end

    delegate :arcgis_api_token_cache_key_prefix,
             :arcgis_api_generate_token_url,
             to: IdentityConfig.store

    attr_accessor :cache_key
  end
end
