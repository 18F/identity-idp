module ArcgisApi::Cache

  # Applies a sliding window strategy to reduce contention
  # related to refreshing the token
  class SlidingWindowRefreshStrategy

    # @param [Number] prefetch_ttl number of seconds used to calculate a sliding_expires_at time
    def initialize(prefetch_ttl: API_PREFETCH_TTL_SECONDS)
      @prefetch_ttl = prefetch_ttl
      @prefetch_ttl += (rand - 0.5) # random jitter
    end

    # @param [ArcgisApi::Token::Authentication] auth
    # @param [ArcgisApi::Token::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Token::TokenInfo]
    def call(auth:, cache:)
      token_entry = cache.token_entry
      now = Time.zone.now.to_f
      if token_entry.present? 
        return token_entry if token_entry.sliding_expires_at > now

        if token_entry.expires_at > now
          token_entry.sliding_expires_at += prefetch_ttl
          cache.save_token(token_entry)
        end
      end

      if token_entry.present? && token_entry.expires_at > now
        # refresh token
      end
        
    end

    private
    API_PREFETCH_TTL_SECONDS = IdentityConfig.store.arcgis_api_token_prefetch_ttl_seconds
    attr_accessor :prefetch_ttl
  end
end