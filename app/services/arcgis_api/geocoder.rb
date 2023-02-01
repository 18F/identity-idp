module ArcgisApi
  class Geocoder
    Suggestion = Struct.new(:text, :magic_key, keyword_init: true)
    AddressCandidate = Struct.new(
      :address, :location, :street_address, :city, :state, :zip_code,
      keyword_init: true
    )
    Location = Struct.new(:latitude, :longitude, keyword_init: true)
    API_TOKEN_CACHE_KEY = :arcgis_api_token

    # These are option URL params that tend to apply to multiple endpoints
    # https://developers.arcgis.com/rest/geocode/api-reference/geocoding-find-address-candidates.htm#ESRI_SECTION2_38613C3FCB12462CAADD55B2905140BF
    COMMON_DEFAULT_PARAMETERS = {
      f: 'json',
      countryCode: 'USA',
      # See https://developers.arcgis.com/rest/geocode/api-reference/geocoding-category-filtering.htm#ESRI_SECTION1_502B3FE2028145D7B189C25B1A00E17B
      #   and https://developers.arcgis.com/rest/geocode/api-reference/geocoding-service-output.htm#GUID-D5C1A6E8-82DE-4900-8F8D-B390C2714A1F
      category: [
        # A subset of a PointAddress that represents a house or building subaddress location,
        #   such as an apartment unit, floor, or individual building within a complex.
        #   E.g. 3836 Emerald Ave, Suite C, La Verne, CA, 91750
        'Subaddress',

        # A street address based on points that represent house and building locations.
        #   E.g. 380 New York St, Redlands, CA, 92373
        'Point Address',

        # A street address that differs from PointAddress because the house number is interpolated
        #   from a range of numbers. E.g. 647 Haight St, San Francisco, CA, 94117
        'Street Address',

        # Similar to a street address but without the house number.
        #   E.g. Olive Ave, Redlands, CA, 92373.
        'Street Name',
      ].join(','),
    }.freeze

    ROOT_URL = IdentityConfig.store.arcgis_api_root_url
    SUGGEST_ENDPOINT = "#{ROOT_URL}/servernh/rest/services/GSA/USA/GeocodeServer/suggest"
    ADDRESS_CANDIDATES_ENDPOINT =
      "#{ROOT_URL}/servernh/rest/services/GSA/USA/GeocodeServer/findAddressCandidates"
    GENERATE_TOKEN_ENDPOINT = "#{ROOT_URL}/portal/sharing/rest/generateToken"

    KNOWN_FIND_ADDRESS_CANDIDATES_PARAMETERS = [
      :magicKey, # Generated from /suggest; identifier used to retrieve full address record
      :SingleLine, # Unvalidated address-like text string used to search for geocoded addresses
    ]

    # Makes an HTTP request to quickly find potential address matches. Each match that is found
    # will include an associated magic_key value which can later be used to get more details about
    # the address using the #find_address_candidates method
    # Requests text input and will only match possible addresses
    # A maximum of 5 suggestions are included in the suggestions array.
    # @param text [String]
    # @return [Array<Suggestion>] Suggestions
    def suggest(text)
      params = {
        text: text,
        **COMMON_DEFAULT_PARAMETERS,
      }

      parse_suggestions(
        faraday.get(SUGGEST_ENDPOINT, params, dynamic_headers) do |req|
          req.options.context = { service_name: 'arcgis_geocoder_suggest' }
        end.body,
      )
    end

    # Makes HTTP request to find a full address record using a magic key or single text line
    # @param options [Hash] one of 'magicKey', which is an ID returned from /suggest,
    #   or 'SingleLine', which should be a single string address that includes at least city
    #   and state.
    # @return [Array<AddressCandidate>] AddressCandidates
    def find_address_candidates(**options)
      supported_params = options.slice(*KNOWN_FIND_ADDRESS_CANDIDATES_PARAMETERS)

      if supported_params.empty?
        raise ArgumentError, <<~MSG
          Unknown parameters: #{options.except(KNOWN_FIND_ADDRESS_CANDIDATES_PARAMETERS)}.
          See https://developers.arcgis.com/rest/geocode/api-reference/geocoding-find-address-candidates.htm
        MSG
      end

      params = {
        outFields: 'StAddr,City,RegionAbbr,Postal',
        **COMMON_DEFAULT_PARAMETERS,
        **supported_params,
      }

      parse_address_candidates(
        faraday.get(ADDRESS_CANDIDATES_ENDPOINT, params, dynamic_headers) do |req|
          req.options.context = { service_name: 'arcgis_geocoder_find_address_candidates' }
        end.body,
      )
    end

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

    # Checks the cache for an unexpired token and returns that.
    # If the cache has expired, retrieves a new token and returns it
    # @return [String] Auth token
    def token
      Rails.cache.read(API_TOKEN_CACHE_KEY) || retrieve_token!
    end

    private

    def faraday
      Faraday.new do |conn|
        # Log request metrics
        conn.request :instrumentation, name: 'request_metric.faraday'

        # Raise an error subclassing Faraday::Error on 4xx, 5xx, and malformed responses
        # Note: The order of this matters for parsing the error response body.
        conn.response :raise_error

        # Parse JSON responses
        conn.response :json, content_type: 'application/json'

        yield conn if block_given?
      end
    end

    def parse_suggestions(response_body)
      handle_api_errors(response_body)

      response_body['suggestions'].map do |suggestion|
        Suggestion.new(
          text: suggestion['text'],
          magic_key: suggestion['magicKey'],
        )
      end
    end

    def parse_address_candidates(response_body)
      handle_api_errors(response_body)

      response_body['candidates'].map do |candidate|
        AddressCandidate.new(
          address: candidate['address'],
          location: Location.new(
            longitude: candidate.dig('location', 'x'),
            latitude: candidate.dig('location', 'y'),
          ),
          street_address: candidate.dig('attributes', 'StAddr'),
          city: candidate.dig('attributes', 'City'),
          state: candidate.dig('attributes', 'RegionAbbr'),
          zip_code: candidate.dig('attributes', 'Postal'),
        )
      end
    end

    # handles API error state when returned as a status of 200
    # @param response_body [Hash]
    def handle_api_errors(response_body)
      if response_body['error']
        error_code = response_body.dig('error', 'code')

        raise Faraday::ClientError.new(
          RuntimeError.new("received error code #{error_code}"),
          response_body,
        )
      end
    end

    # Retrieve the short-lived API token (if needed) and then pass
    # the headers to an arbitrary block of code as a Hash.
    #
    # Returns the same value returned by that block of code.
    def dynamic_headers
      { 'Authorization' => "Bearer #{token}" }
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

      faraday.post(GENERATE_TOKEN_ENDPOINT, URI.encode_www_form(body)) do |req|
        req.options.context = { service_name: 'usps_token' }
      end.body
    end
  end
end
