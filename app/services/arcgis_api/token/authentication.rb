module ArcgisApi::Token
  # Authenticate with the ArcGIS API
  class Authentication
    # Makes a request to retrieve a new token
    # it expires after 1 hour
    # @return [ArcgisApi::Token::TokenInfo] Auth token
    def retrieve_token
      token, expires = request_token.fetch_values('token', 'expires')
      expires_at = Time.zone.at(expires / 1000).to_f
      return ArcgisApi::TokenInfo.new(token: token, expires_at: expires_at)
    end

    private

    # Makes HTTP request to authentication endpoint and
    # returns the token and when it expires (1 hour).
    # @return [Hash] API response
    def request_token
      body = {
        username: arcgis_api_username,
        password: arcgis_api_password,
        referer: domain_name,
        f: 'json',
      }

      connection.post(
        arcgis_api_generate_token_url, URI.encode_www_form(body)
      ) do |req|
        req.options.context = { service_name: 'arcgis_token' }
      end.body
    end

    def connection
      faraday_retry_options = {
        retry_statuses: RETRY_HTTP_STATUS,
        max: arcgis_get_token_max_retries,
        methods: %i[post],
        interval: arcgis_get_token_retry_interval_seconds,
        interval_randomness: 0.25,
        backoff_factor: arcgis_get_token_retry_backoff_factor,
        exceptions: [Errno::ETIMEDOUT, Timeout::Error, Faraday::TimeoutError, Faraday::ServerError,
                     Faraday::ClientError, Faraday::RetriableResponse,
                     ArcgisApi::Token::InvalidResponseError],
        retry_block: ->(env:, options:, retry_count:, exception:, will_retry_in:) {
          # log analytics event
          exception_message = exception_message(exception, options, retry_count, will_retry_in)
          notify_retry(env, exception_message)
        },
      }
      Faraday.new do |conn|
        # Log request metrics
        conn.request :instrumentation, name: 'request_metric.faraday'
        conn.options.timeout = arcgis_api_request_timeout_seconds
        # Parse JSON responses
        conn.response :json, content_type: 'application/json'
        # Raise an error subclassing Faraday::Error on 4xx, 5xx, and malformed responses
        # Note: The order of this matters for parsing the error response body.
        conn.response :raise_error
        conn.request :retry, faraday_retry_options
        conn.use ArcgisApi::ResponseValidation
        yield conn if block_given?
      end
    end

    def notify_retry(env, exception_message)
      body = env.body
      case body
      when Hash
        resp_body = body
      when String
        resp_body = begin
          JSON.parse(body)
        rescue
          body
        end
      else
        resp_body = body
      end
      http_status = env.status
      api_status_code = resp_body.is_a?(Hash) ? resp_body.dig('error', 'code') : http_status
      analytics.idv_arcgis_token_failure(
        exception_class: 'ArcGIS',
        exception_message: exception_message,
        response_body_present: resp_body.present?,
        response_body: resp_body,
        response_status_code: http_status,
        api_status_code: api_status_code,
      )
    end

    def exception_message(exception, options, retry_count, will_retry_in)
      # rubocop:disable Layout/LineLength
      if options.max == retry_count + 1
        exception_message = "token request max retries(#{options.max}) reached, error : #{exception.message}"
      else
        exception_message =
          "token request retry count : #{retry_count}, will retry in #{will_retry_in}, error : #{exception.message}"
      end
      # rubocop:enable Layout/LineLength
      exception_message
    end

    delegate :arcgis_api_username,
             :arcgis_api_password,
             :domain_name,
             :arcgis_api_generate_token_url,
             :arcgis_get_token_max_retries,
             :arcgis_get_token_retry_interval_seconds,
             :arcgis_get_token_retry_backoff_factor,
             :arcgis_api_request_timeout_seconds,
             to: IdentityConfig.store
  end

  class InvalidResponseError < Faraday::Error
  end
end
