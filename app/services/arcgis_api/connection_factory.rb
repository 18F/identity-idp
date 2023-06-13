module ArcgisApi
  # Stateless and thread-safe factory object that create a new Faraday::Connection object.
  class ConnectionFactory
    # @param [String|URI] url
    # @options [Hash] Faraday connection options
    # @return Faraday::Connection
    def connection(url = nil, options = {})
      conn_options = options ? options.dup : {}
      Faraday.new(url, conn_options) do |conn|
        # Log request metrics
        conn.request :instrumentation, name: 'request_metric.faraday'
        conn.options.timeout = IdentityConfig.store.arcgis_api_request_timeout_seconds
        # Parse JSON responses
        conn.response :json, content_type: 'application/json'
        # Raise an error subclassing Faraday::Error on 4xx, 5xx, and malformed responses
        # Note: The order of this matters for parsing the error response body.
        conn.response :raise_error
        yield conn if block_given?
      end
    end
  end
end
