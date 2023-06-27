# Utility functions for configuring Faraday for use with the ArcGIS API
module ArcgisApi::Faraday::Configuration
  # Configure Faraday to communicate with the ArcGIS API
  #
  # @param [Faraday::Connection] conn
  def self.setup(conn)
    # Log request metrics
    conn.request :instrumentation, name: 'request_metric.faraday'
    conn.options.timeout = arcgis_api_request_timeout_seconds
    # Parse JSON responses
    conn.response :json, content_type: 'application/json'
    # Raise an error subclassing Faraday::Error on 4xx, 5xx, and malformed responses
    # Note: The order of this matters for parsing the error response body.
    conn.response :raise_error
    conn.use ArcgisApi::Faraday::ResponseValidation
  end

  # Configure retries on the Faraday connection, and optionally
  # configure the retry_block parameter for the retry middleware.
  #
  # Also see: https://github.com/lostisland/faraday-retry
  #
  # @param [Faraday::Connection] conn
  # @yield [env:, options:, retry_count:, exception:, will_retry_in:]
  def self.add_retry(conn, &block)
    faraday_retry_options = {
      max: arcgis_get_token_max_retries,
      methods: %i[post],
      interval: arcgis_get_token_retry_interval_seconds,
      interval_randomness: 0.25,
      backoff_factor: arcgis_get_token_retry_backoff_factor,
    }

    # If a block was given, then run it before each retry
    faraday_retry_options[:retry_block] = Proc.new(&block) if block

    conn.request :retry, faraday_retry_options
  end

  class << self
    private

    delegate :arcgis_get_token_max_retries,
             :arcgis_get_token_retry_interval_seconds,
             :arcgis_get_token_retry_backoff_factor,
             :arcgis_api_request_timeout_seconds,
             to: :"IdentityConfig.store"
  end
end
