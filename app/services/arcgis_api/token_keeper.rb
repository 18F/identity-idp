module ArcgisApi
  # Class for retrieve, refresh and manage caching of Arcgis API token.
  # @attr_reader [connection] The underlying Faraday::Connection
  # @attr_writer [prefetch_ttl] number of seconds to control timing of requesting a new token

  # The token is saved in cache as a hash
  # @example cache entry
  # {
  #   value: "XXXXXXXXXX",
  #   sliding_expires_at: xxxxxxx,
  #   expires_at: xxxxxxxxx,
  # }
  # expires_at: unix time that the token will expire, returned from the Arcgis API generateToken call.
  #
  # sliding_expires_at: a time that the token does not actually expire but used to control timing of
  # requesting a new token before it expires. It's initially set to expires_at - 3*prefetch_ttl.
  #
  # When sliding_expires_at<= current time <= sliding_expires_at + prefetch_ttl, the entry's sliding_expires_at
  # time is updated to sliding_expires_at + prefetch_ttl and a new token is requested and saved to cache.
  #
  # When sliding_expires_at + prefetch_ttl < current time, a new token is requested and saved to cache.
  #
  # Optimistically, the token in cache will NOT expire when accessed by multi-threaded/distributed clients.
  # Since there is about prefetch_ttl - 2*prefetch_ttl length of time to generate a new API token.
  #
  class TokenKeeper
    API_TOKEN_HOST = URI(IdentityConfig.store.arcgis_api_generate_token_url).host
    API_TOKEN_CACHE_KEY = "arcgis_api_token:#{API_TOKEN_HOST}"
    API_PREFETCH_TTL_SECONDS = 10

    attr_accessor :connection_factory, :prefetch_ttl, :cache_key, :analytics

    # @param [Faraday::Connection] conn
    # @param [Number] prefetch_ttl number of seconds used to calculate a sliding_expires_at time
    def initialize(cache_key, connection_factory, prefetch_ttl)
      @cache_key = cache_key || API_TOKEN_CACHE_KEY
      @connection_factory = connection_factory || ArcgisApi::ConnectionFactory.new
      @prefetch_ttl = prefetch_ttl && prefetch_ttl > 0 ? prefetch_ttl : API_PREFETCH_TTL_SECONDS
      @analytics = Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
    end

    # Checks the cache for an unexpired token and returns that.
    # If the cache has expired, retrieves a new token and returns it
    # @return [String] Auth token
    def token
      cache_value = Rails.cache.read(API_TOKEN_CACHE_KEY) || retrieve_token!
      cache_value = wrap_raw_token(cache_value) unless cache_value.is_a?(Hash)
      expires_at = cache_value&.fetch(:expires_at, nil)
      sliding_expires_at = cache_value&.fetch(:sliding_expires_at, nil)
      # start fetch new token before actual expires time
      Rails.logger.debug { "### gettting token #{cache_value}" }
      if IdentityConfig.store.arcgis_token_sliding_expiration_enabled
        Rails.logger.debug 'here########'
        now = Time.zone.now.to_f
        if sliding_expires_at && now >= sliding_expires_at
          Rails.logger.debug '### passed sliding expires_at'
          # if passed sliding expiration time(exp-3*prefetch_ttl) but not 2*prefetch_ttl from hard expiration time
          if now > (sliding_expires_at + prefetch_ttl)
            Rails.logger.debug '### get new token'
            cache_value = retrieve_token!
          else
            # extend sliding expiration time
            cache_value[:sliding_expires_at] = sliding_expires_at + prefetch_ttl
            save_token(cache_value, expires_at)
          end
        else
          Rails.logger.debug { "Not passed sliding windown #{sliding_expires_at}, #{now}" }
        end
      elsif expires_at && expires_at <= now
        cache_value = retrieve_token!
      end
      cache_value&.fetch(:token)
    end

    def fetch_save_token
      retrieve_token!
    end

    # @param [Object] cache_value the entry to save in cache
    # @param [Number] expires_at the unix time cache entry should expire
    def save_token(cache_value, expires_at)
      Rails.cache.write(API_TOKEN_CACHE_KEY, cache_value, expires_at: expires_at)
      # If using a redis cache we have to manually set the expires_at. This is because we aren't
      # using a dedicated Redis cache and instead are just using our existing Redis server with
      # mixed usage patterns. Without this cache entries don't expire.
      # More at https://api.rubyonrails.org/classes/ActiveSupport/Cache/RedisCacheStore.html
      Rails.cache.try(:redis)&.expireat(API_TOKEN_CACHE_KEY, expires_at.to_i)
    end

    private

    # Makes a request to retrieve a new token
    # it expires after 1 hour
    # @return [String] Auth token
    def retrieve_token!
      token, expires = request_token.fetch_values('token', 'expires')
      expires_at = Time.zone.at(expires / 1000).to_f
      cache_entry = {
        token: token,
        expires_at: expires_at,
      }

      if IdentityConfig.store.arcgis_token_sliding_expiration_enabled == true
        cache_entry = cache_entry.merge({ sliding_expires_at: prefetch_ttl >= 0 ? expires_at - 3 * prefetch_ttl : expires_at })
      end
      Rails.logger.debug { "####save token: #{cache_entry}" }
      save_token(cache_entry, expires_at)
      cache_entry
    end

    # Makes HTTP request to authentication endpoint and
    # returns the token and when it expires (1 hour).
    # @return [Hash] API response
    def request_token
      body = {
        username: IdentityConfig.store.arcgis_api_username,
        password: IdentityConfig.store.arcgis_api_password,
        referer: IdentityConfig.store.domain_name,
        f: 'json',
      }

      connection.post(
        IdentityConfig.store.arcgis_api_generate_token_url, URI.encode_www_form(body)
      ) do |req|
        req.options.context = { service_name: 'arcgis_token' }
      end.body
    end

    def connection
      faraday_retry_options = {
        retry_statuses: (400..500).to_a,
        max: IdentityConfig.store.arcgis_get_token_retry_max,
        methods: %i[post],
        interval: IdentityConfig.store.arcgis_get_token_retry_interval,
        backoff_factor: IdentityConfig.store.arcgis_get_token_retry_backoff_factor,
        exceptions: [Errno::ETIMEDOUT, Timeout::Error, Faraday::TimeoutError, Faraday::ServerError, Faraday::ClientError,
                     Faraday::RetriableResponse],
        retry_block: ->(env:, options:, retry_count:, exception:, will_retry_in:) {
          # log analytics event
          notify_retry(env, exception, retry_count, will_retry_in)
        }
      }
      connection_factory.connection do |conn|
        conn.request :retry, faraday_retry_options
        #conn.response :arcgis_response_validation
        conn.use ResponseValidation
      end
    end

    def wrap_raw_token(token, expires_at = nil)
      {
        token: token,
        expires_at: expires_at,
      }
    end

    def handle_api_errors(response_body)
      if response_body['error']
        # response_body is in this format:
        # {"error"=>{"code"=>400, "message"=>"", "details"=>[""]}}
        error_code = response_body.dig('error', 'code')
        error_message = response_body.dig('error', 'message') || "Received error code #{error_code}"
        # log an error
        analytics.idv_arcgis_request_failure(
          exception_class: 'ArcGIS',
          exception_message: error_message,
          response_body_present: false,
          response_body: '',
          response_status_code: error_code,
          api_status_code: error_code,
        )
        Rails.cache.delete(API_TOKEN_CACHE_KEY) # this might only be needed for local testing
        raise Faraday::RetriableResponse.new(
          RuntimeError.new(error_message),
          {
            status: error_code,
            body: { details: response_body.dig('error', 'details')&.join(', ') },
          },
        )
      end
    end

    def notify_retry(env, exception, retry_count, will_retry_in)
      analytics.idv_arcgis_request_failure(
        exception_class: 'ArcGIS',
        exception_message: "token request retry count : #{retry_count}, will retry in #{will_retry_in}, error : #{exception.to_s}",
        response_body_present: false,
        response_body: env.body,
        response_status_code: 200,
        api_status_code: 200,
      )
    end
  end
end
