module ArcgisApi::Auth::Refresh
  # Applies a sliding window strategy to reduce contention
  # related to refreshing the token.
  #
  # When sliding_expires_at<= current time <= sliding_expires_at + prefetch_ttl,
  # the entry's sliding_expires_at time is updated to
  # sliding_expires_at + prefetch_ttl and a new token is requested and saved to cache.
  #
  # When sliding_expires_at + prefetch_ttl < current time,
  # a new token is requested and saved to cache.
  #
  # Optimistically, the token in cache will NOT expire
  # when accessed by multi-threaded/distributed clients,
  # since there is about expires_at - 2*prefetch_ttl
  # length of time to generate a new API token.
  class SlidingWindowRefreshStrategy < RefreshStrategy
    # @param [Number] sliding_increment_seconds size of increment to use for the sliding window
    # @param [Number] sliding_times times to move the window by sliding_increment_seconds
    def initialize(sliding_increment_seconds: nil, sliding_times: nil)
      @sliding_increment_seconds = (
        sliding_increment_seconds ||
        arcgis_api_token_prefetch_ttl_sliding_increment_seconds
      )
      @sliding_times = (
        sliding_times ||
        arcgis_api_token_prefetch_ttl_sliding_times
      )

      # Add jitter to reduce the likelihood that cache updates
      # will coincide with other sources of load on the API
      # and cache servers
      @sliding_increment_seconds += (rand - 0.5)
    end

    # @param [ArcgisApi::Auth::Authentication] auth
    # @param [ArcgisApi::Auth::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Auth::Token]
    def call(auth:, cache:)
      token_entry = cache.token_entry
      if token_entry.present?
        return token_entry unless token_entry.sliding_window_expired?

        # If we've reached the sliding window, then extend the
        # sliding window to prevent other servers from refreshing
        # the same token
        unless token_entry.expired?
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
