module ArcgisApi::Auth::Cache
  class TokenCacheInfoWriter < TokenCacheWriter

    # @param [ArcgisApi::Auth::Token] cache_value the value to write to cache
    def save_token(cache_value)
      token_cache.save_token(cache_value, expires_at: cache_value.expires_at)
    end
  end
end