module ArcgisApi
  module TokenUtil
    API_TOKEN_HOST = URI(IdentityConfig.store.arcgis_api_generate_token_url).host
    API_TOKEN_CACHE_KEY = "arcgis_api_token:#{API_TOKEN_HOST}"
    API_PREFETCH_TTL_SECONDS = 10



    # Checks the cache for an unexpired token and returns that.
    # If the cache has expired, retrieves a new token and returns it
    # @return [String] Auth token
    def token
      Rails.cache.fetch(API_TOKEN_CACHE_KEY, race_condition_ttl: API_PREFETCH_TTL_SECONDS.seconds) do
        retrieve_token!
      end
    end

    private

    # Makes a request to retrieve a new token
    # it expires after 1 hour
    # @return [String] Auth token
    def retrieve_token!
      token, expires = request_token.fetch_values('token', 'expires')
      expires_at = Time.zone.at(expires / 1000)
      Rails.cache.write(API_TOKEN_CACHE_KEY, token, expires_at: expires_at)
      # If using a redis cache we have to manually set the expires_at. This is because we aren't
      # using a dedicated Redis cache and instead are just using our existing Redis server with
      # mixed usage patterns. Without this cache entries don't expire.
      # More at https://api.rubyonrails.org/classes/ActiveSupport/Cache/RedisCacheStore.html
      Rails.cache.try(:redis)&.expireat(API_TOKEN_CACHE_KEY, expires_at.to_i)
      token
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

      faraday.post(
        IdentityConfig.store.arcgis_api_generate_token_url, URI.encode_www_form(body)
      ) do |req|
        req.options.context = { service_name: 'arcgis_token' }
      end.body.tap do |body|
        handle_api_errors(body)
      end
    end
  end
end
