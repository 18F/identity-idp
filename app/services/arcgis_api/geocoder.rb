module ArcgisApi
  class Geocoder
    Suggestion = Struct.new(:text, :magic_key, keyword_init: true)
    AddressCandidate = Struct.new(
      :address, :location, :street_address, :city, :state, :zip_code,
      keyword_init: true
    )
    COMMON_DEFAULTS = {
      f: 'json',
      countryCode: 'USA',
      category: 'address',
    }

    # Makes HTTP request to quickly find potential address matches
    # Requests text input and will only match possible addresses
    # A maximum of 5 suggestions are included in the suggestions array.
    # @param text [String]
    # @return [Array<Suggestion>] Suggestions
    def suggest(text)
      url = "#{root_url}/suggest"
      params = {
        text: text,
        **COMMON_DEFAULTS,
      }

      parse_suggestions(
        faraday.get(url, params) do |req|
          req.options.context = { service_name: 'arcgis_geocoder_suggest' }
        end.body,
      )
    end

    # Makes HTTP request to find an exact address using magic_key
    # Requires a magic_key returned from a previous response from #suggest
    # @param magic_key [String]
    # @return [Array<AddressCandidate>] AddressCandidates
    def find_address_candidates(magic_key)
      url = "#{root_url}/findAddressCandidates"
      params = {
        magicKey: magic_key,
        outFields: '*',
        **COMMON_DEFAULTS,
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
