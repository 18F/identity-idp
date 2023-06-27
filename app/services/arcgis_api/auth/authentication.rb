module ArcgisApi::Auth
  # Authenticate with the ArcGIS API
  class Authentication
    def initialize(analytics: nil)
      @analytics = analytics || Analytics.new(
        user: AnonymousUser.new,
        request: nil,
        session: {},
        sp: nil,
      )
    end

    # Makes a request to retrieve a new token
    # it expires after 1 hour
    # @return [ArcgisApi::Auth::Token] Auth token
    def retrieve_token
      token, expires = request_token.fetch_values('token', 'expires')
      expires_at = Time.zone.at(expires / 1000).to_f
      return ArcgisApi::Auth::Token.new(token: token, expires_at: expires_at)
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
      ::Faraday.new do |conn|
        ArcgisApi::Faraday::Configuration.setup(conn)
        ArcgisApi::Faraday::Configuration.add_retry(conn) do |**args|
          log_retry(**args)
        end
        yield conn if block_given?
      end
    end

    # @param [Faraday::Env] env Request environment
    # @param [Faraday::Options] options middleware options
    # @param [Integer] retry_count how many retries have already occured (starts at 0)
    # @param [Exception] exception exception that triggered the retry,
    #        will be the synthetic `Faraday::RetriableResponse` if the
    #        retry was triggered by something other than an exception.
    # @param [Float] will_retry_in retry_block is called *before* the retry
    #        delay, actual retry will happen in will_retry_in number of
    #        seconds.
    def log_retry(env:, options:, retry_count:, exception:, will_retry_in:)
      resp_body = env.body.then do |body|
        if body.is_a?(String)
          JSON.parse(body)
        else
          body
        end
      rescue
        body
      end

      http_status = env.status
      api_status_code = resp_body.is_a?(Hash) ? resp_body.dig('error', 'code') : http_status
      analytics.idv_arcgis_token_failure(
        exception_class: exception.class.name,
        exception_message: exception.message,
        response_body_present: resp_body.present?,
        response_body: resp_body,
        response_status_code: http_status,
        api_status_code: api_status_code,

        # Include retry-specific data
        retry_count:,
        retry_max: options.max,
        will_retry_in:,
      )
    end

    attr_accessor :analytics

    delegate :arcgis_api_username,
             :arcgis_api_password,
             :domain_name,
             :arcgis_api_generate_token_url,
             to: :"IdentityConfig.store"
  end
end
