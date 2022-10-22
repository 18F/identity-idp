module ArcgisApi
  class Geocoder
    Suggestion = Struct.new(:text, :magic_key, keyword_init: true)

    # Makes HTTP request to get potential address matches
    # Requests text input and will only match possible addresses
    # A maximum of 5 suggestions are included in the suggestions array.
    # @param text [String]
    # @return [Array<Suggestion>] Suggestions
    def suggest(text)
      url = "#{root_url}/suggest"
      params = {
        text: text,
        category: 'address',
        countryCode: 'USA',
        f: 'json',
      }

      parse_suggestions(
        faraday.get(url, params) do |req|
          req.options.context = { service_name: 'arcgis_geocoder_suggest' }
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
      if response_body['error']
        error_code = response_body.dig('error', 'code')

        raise Faraday::ClientError.new(RuntimeError.new("received error code #{error_code}"), response_body)
      end

      response_body['suggestions'].map do |suggestion|
        Suggestion.new(
          text: suggestion['text'],
          magic_key: suggestion['magicKey'],
        )
      end
    end
  end
end
