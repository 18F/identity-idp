module ArcgisApi::Cache
  class TokenCacheRawWriter < ArcgisApi::Cache::TokenCacheReader

    # @param [ArcgisApi::TokenInfo] cache_value the value to write to cache
    def save_token(cache_value)
      token_cache.save_token(cache_value.token, expires_at: cache_value.expires_at)
    end
  end
end