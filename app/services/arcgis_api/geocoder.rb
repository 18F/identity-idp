module ArcgisApi
  class Geocoder
    Suggestion = Struct.new(:text, :magic_key, keyword_init: true)
    AddressCandidate = Struct.new(
      :address, :location, :street_address, :city, :state, :zip_code,
      keyword_init: true
    )

    # These are option URL params that tend to apply to multiple endpoints
    # https://developers.arcgis.com/rest/geocode/api-reference/geocoding-find-address-candidates.htm#ESRI_SECTION2_38613C3FCB12462CAADD55B2905140BF
    COMMON_DEFAULT_PARAMETERS = {
      f: 'json',
      countryCode: 'USA',
      category: 'address',
    }

    # Makes an HTTP request to quickly find potential address matches. Each match that is found
    # will include an associated magic_key value which can later be used to get more details about
    # the address using the #find_address_candidates method
    # Requests text input and will only match possible addresses
    # A maximum of 5 suggestions are included in the suggestions array.
    # @param text [String]
    # @return [Array<Suggestion>] Suggestions
    def suggest(text)
      url = "#{root_url}/suggest"
      params = {
        text: text,
        **COMMON_DEFAULT_PARAMETERS,
      }

      parse_suggestions(
        faraday.get(url, params) do |req|
          req.options.context = { service_name: 'arcgis_geocoder_suggest' }
        end.body,
      )
    end

    # Makes HTTP request to find an exact address using magic_key
    # @param magic_key [String] a magic key value from a previous call to the #suggest method
    # @return [Array<AddressCandidate>] AddressCandidates
    def find_address_candidates(magic_key)
      url = "#{root_url}/findAddressCandidates"
      params = {
        magicKey: magic_key,
        outFields: 'StAddr,City,RegionAbbr,Postal',
        **COMMON_DEFAULT_PARAMETERS,
      }

      parse_address_candidates(
        faraday.get(url, params) do |req|
          req.options.context = { service_name: 'arcgis_geocoder_find_address_candidates' }
        end.body,
      )
    end

    private

    def root_url
      IdentityConfig.store.arcgis_api_root_url
    end

    def faraday
      Faraday.new(headers: request_headers) do |conn|
        # Log request metrics
        conn.request :instrumentation, name: 'request_metric.faraday'

        # Raise an error subclassing Faraday::Error on 4xx, 5xx, and malformed responses
        # Note: The order of this matters for parsing the error response body.
        conn.response :raise_error

        # Parse JSON responses
        conn.response :json, content_type: 'application/json'
      end
    end

    def request_headers
      { 'Authorization' => "Bearer #{IdentityConfig.store.arcgis_api_key}" }
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
          location: candidate['location'],
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
  end
end
