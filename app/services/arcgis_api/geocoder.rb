module ArcgisApi
  class Geocoder
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
        end.body
      )
    end

    def findAddressCandidates
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

        # Convert body to JSON
        conn.request :json

        # Parse JSON responses
        conn.response :json
      end
    end

    def request_headers
      { 'Authorization' => "Bearer #{IdentityConfig.store.arcgis_api_key}" }
    end

    def parse_suggestions(suggestions)
      suggestions['suggestions'].map do |suggestion|
        {
          text: suggestion['text'],
          magicKey: suggestion['magicKey']
        }
      end
    end
  end
end
