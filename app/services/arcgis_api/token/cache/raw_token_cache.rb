module ArcgisApi::Token::Cache
  class RawTokenCache

    def initialize(
      cache: Cache::CacheWrapper.new,
      cache_key: DEFAULT_API_TOKEN_CACHE_KEY,
    )
      @cache = cache
      @cache_key = cache_key
    end

    # @return [Object,nil] Cached auth token
    def token
      raw_token = cache.read(cache_key)
      if raw_token
        raw_token
      else
        nil
      end
    end

    # @param [Object,nil] cache_value the value to write to cache
    # @param [Number] expires_at the hard expiration time in unix time (milliseconds)
    def save_token(cache_value, expires_at)
      cache.write(cache_key, cache_value, expires_at)
    end

    private

    API_TOKEN_CACHE_KEY = "#{IdentityConfig.store.arcgis_api_token_cache_key_prefix}:#{
      URI(IdentityConfig.store.arcgis_api_generate_token_url).host
    }"

    attr_accessor :cache_key
  end
end