module ArcgisApi
  # Class for retrieve, refresh and manage caching of Arcgis API token.
  # If token synchronous fetching is disabled, a token will be fetched from
  # cache directly or it will be a cache miss.
  # Otherwise the thread will try to fetch/refresh the token on demand as needed.
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
  class TokenKeeper
    API_PREFETCH_TTL_SECONDS = IdentityConfig.store.arcgis_api_token_prefetch_ttl_seconds

    RETRY_HTTP_STATUS = [404, 408, 409, 421, 429, 500, 502, 503, 504, 509]

    TIMES_TTL = 3

    attr_accessor :prefetch_ttl, :analytics, :sliding_expiration_enabled,
                  :expiration_strategy

    # @param [String] cache_key token cache key
    # @param [Number] prefetch_ttl number of seconds used to calculate a sliding_expires_at time
    def initialize(prefetch_ttl: API_PREFETCH_TTL_SECONDS)
      @prefetch_ttl = (prefetch_ttl && prefetch_ttl > 0 ? prefetch_ttl : API_PREFETCH_TTL_SECONDS)
      @prefetch_ttl += (rand - 0.5) # random jitter
      @analytics = Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
      @sliding_expiration_enabled =
        IdentityConfig.store.arcgis_token_sliding_expiration_enabled
      @expiration_strategy =
        TokenExpirationStrategy.new(sliding_expiration_enabled: sliding_expiration_enabled)
    end

    # Makes a request to retrieve a new token
    # it expires after 1 hour
    # @return [ArcgisApi::TokenInfo] Auth token
    def retrieve_token
      token, expires = request_token.fetch_values('token', 'expires')
      expires_at = Time.zone.at(expires / 1000).to_f
      return ArcgisApi::TokenInfo.new(token: token, expires_at: expires_at)
    end

    def save_token
    end

    def token
    end

    private

    # Checks the cache for an unexpired token and returns that.
    # If the cache has expired, retrieves a new token and returns it
    # @return [ArcgisApi::TokenInfo] Auth token
    def token_entry
      cache_value = super
      return cache_value unless IdentityConfig.store.arcgis_token_sync_request_enabled
      # go get new token if needed and sync request enabled
      if cache_value.nil?
        cache_entry = retrieve_token
        expires_at = cache_entry.expires_at
        if sliding_expiration_enabled
          cache_entry.sliding_expires_at = prefetch_ttl >= 0 ?
                                             expires_at - TIMES_TTL * prefetch_ttl : expires_at
        end
        save_token(cache_entry, expires_at)
        cache_entry
      else
        process_expired_token(cache_value)
      end
    end

    # Core logic on what to do  when a token sliding-expired (very close to expiration time).
    # Ideally this wont be invoked when there is a cache miss(already hard expired).
    # Sliding expiration gives the application a buffer to preemptively get new token and
    # avoid affecting large number of workers near the real expiration time.
    # When it's sliding expired. the current worker first extend the sliding_expires_at
    # time with an additional prefetch_ttl seconds (to mitigate chances other workers
    # doing the same thing, not bullet proof, unless we have a single locking mechanism),
    # then go ahead request a new token from arcgis and save it to cache.
    #
    # @param [ArcgisApi::TokenInfo] cache_value existing cache_entry, non nil value
    # @return [ArcgisApi::TokenInfo] retrieve and save a new token if expired,
    #   or extend sliding_expires_at if needed
    def process_expired_token(cache_value)
      return cache_value unless expiration_strategy.expired?(
        token_info: cache_value,
      )
      # process sliding expired cache_value
      # extend the sliding_expires_at with additional prefetch_ttl seconds value if needed
      current_sliding_expires_at = cache_value.sliding_expires_at
      expiration_strategy.
        extend_sliding_expires_at(token_info: cache_value, prefetch_ttl: prefetch_ttl)
      # avoid extra call if needed when nothing changes
      if current_sliding_expires_at != cache_value.sliding_expires_at
        save_token(
          cache_value,
          cache_value.expires_at,
        )
      end

      # now retrieve new token
      update_value = retrieve_token
      expires_at = update_value&.expires_at
      if sliding_expiration_enabled
        update_value.sliding_expires_at = prefetch_ttl >= 0 ?
                                            expires_at - TIMES_TTL * prefetch_ttl : expires_at
      end
      save_token(
        update_value,
        update_value.expires_at,
      )
      return update_value
    end
  end

  class TokenExpirationStrategy
    attr_accessor :sliding_expiration_enabled

    def initialize(sliding_expiration_enabled:)
      @sliding_expiration_enabled = sliding_expiration_enabled
    end

    # Check whether a token_info expired or not. It's considered not expired
    # when has no expires_at field.
    # If expires_at time is past, then it's expired. Otherwise, check sliding_expires_at when
    # sliding expiration is enabled, and it's considered expired when sliding_expires_at time
    # is over prefetch_ttl seconds.
    #
    # @param [ArcgisApi::TokenInfo] token_info
    # @return [true|false] whether it's considered expired
    def expired?(token_info:)
      return true unless token_info
      expires_at = token_info&.expires_at
      return false unless expires_at
      now = Time.zone.now.to_f
      # hard expired
      return true if expires_at && expires_at <= now
      # sliding expired
      if sliding_expiration_enabled
        sliding_expires_at = token_info&.sliding_expires_at
        return true if sliding_expires_at && now >= sliding_expires_at
      end
      return false
    end

    # update sliding_expires_at if necessary and extend it prefetch_ttl seconds
    def extend_sliding_expires_at(token_info:, prefetch_ttl:)
      if sliding_expiration_enabled && token_info&.sliding_expires_at
        token_info.sliding_expires_at += prefetch_ttl
      end
      token_info
    end
  end
end
