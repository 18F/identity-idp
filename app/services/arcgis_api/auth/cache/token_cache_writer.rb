module ArcgisApi::Auth::Cache
  class TokenCacheWriter < TokenCacheReader
    # @param [ArcgisApi::Auth::Token] cache_value the value to write to cache
    def save_token(cache_value); end
  end
end
