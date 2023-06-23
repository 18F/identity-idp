module ArcgisApi::Auth::Cache
  class TokenCacheReader
    # @param [ArcgisApi::Auth::Cache::RawTokenCache] token_cache
    def initialize(token_cache: nil)
      @token_cache = token_cache || ArcgisApi::Auth::Cache::RawTokenCache.new
    end

    # @return [String,nil] auth token
    def token
      token_entry&.token
    end

    # Fetch, wrap, and return cache entry for ArcGIS API token
    # @return [ArcgisApi::Auth::Token,nil] token, or nil if not present in cache
    def token_entry
      cache_entry = token_cache.token

      if cache_entry.is_a?(String)
        ArcgisApi::Auth::Token.new(
          token: token,
        )
      elsif cache_entry.is_a?(ArcgisApi::Auth::Token)
        cache_entry
      end
    end

    protected

    attr_accessor :token_cache
  end
end
