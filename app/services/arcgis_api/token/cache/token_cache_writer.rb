module ArcgisApi::Token::Cache
  class TokenCacheWriter < TokenCacheReader
    # @param [ArcgisApi::Token::TokenInfo] cache_value the value to write to cache
    def save_token(cache_value); end
  end
end
