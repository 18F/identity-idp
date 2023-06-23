module ArcgisApi::Token::Cache
  class TokenCacheReader
    def initialize(token_cache: ArcgisApi::Token::Cache::RawTokenCache.new)
      @token_cache = token_cache
    end

    # @return [String,nil] auth token
    def token
      token_entry&.token
    end

    # Fetch, wrap, and return cache entry for ArcGIS API token
    # @return [ArcgisApi::Token::TokenInfo,nil] token, or nil if not present in cache
    def token_entry
      cache_entry = token_cache.token

      if cache_entry.is_a?(String)
        ArcgisApi::TokenInfo.new(
          token: token,
        )
      elsif cache_entry.is_a?(ArcgisApi::TokenInfo)
        cache_entry
      end
    end

    protected

    attr_accessor :token_cache
  end
end
