module ArcgisApi::Cache
  class TokenCacheReader
    def initialize(token_cache: ArcgisApi::Cache::RawTokenCache.new)
      @token_cache = token_cache
    end

    # @return [String|nil] auth token
    def token
      token_entry&.token
    end

    # @return [ArcgisApi:TokenInfo|nil] fetch cache entry and wrap it necessary, if miss return nil
    def token_entry
      cache_entry = token_cache.token

      if cache_entry.is_a?(String)
        wrap_raw_token(cache_entry)
      elsif cache_entry.is_a?(ArcgisApi::TokenInfo)
        cache_entry
      else
        nil
      end
    end

    protected

    attr_accessor :token_cache

    private

    def wrap_raw_token(token, expires_at = nil)
      ArcgisApi::TokenInfo.new(
        token: token,
        expires_at: expires_at,
      )
    end
  end
end