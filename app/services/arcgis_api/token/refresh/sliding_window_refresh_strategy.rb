module ArcgisApi::Token::Refresh

  # Applies a sliding window strategy to reduce contention
  # related to refreshing the token
  class SlidingWindowRefreshStrategy < RefreshStrategy

    # @param [Number] sliding_increment_seconds size of increment to use for the sliding window
    # @param [Number] sliding_times times to allow the sliding window to move by sliding_increment_seconds
    def initialize(
      sliding_increment_seconds:
        arcgis_api_token_prefetch_ttl_sliding_increment_seconds,
      sliding_times:
        arcgis_api_token_prefetch_ttl_sliding_times,
    )
      @sliding_increment_seconds = sliding_increment_seconds

      # Add jitter to reduce the likelihood that cache updates
      # will coincide with other sources of load on the API
      # and cache servers
      @sliding_increment_seconds += (rand - 0.5)
    end

    # @param [ArcgisApi::Token::Authentication] auth
    # @param [ArcgisApi::Token::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Token::TokenInfo]
    def call(auth:, cache:)
      token_entry = cache.token_entry
      if token_entry.present? 
        # If we've reached the sliding window, then extend the
        # sliding window to prevent other servers from refreshing
        # the same token
        unless token_entry.sliding_window_expired?
          return token_entry
        else unless token_entry.expired?
          token_entry.sliding_expires_at += sliding_increment_seconds
          cache.save_token(token_entry)
        end
      end

      new_token = auth.retrieve_token

      sliding_expires_at = sliding_increment_seconds * sliding_times
      new_token.sliding_expires_at = new_token.expires_at - sliding_expires_at

      cache.save_token(new_token)
      new_token
    end

    private
    delegate :arcgis_api_token_prefetch_ttl_sliding_increment_seconds,
             :arcgis_api_token_prefetch_ttl_sliding_times,
             to: IdentityConfig.store
    attr_accessor :sliding_increment_seconds, :sliding_times
  end
end