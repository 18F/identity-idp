# frozen_string_literal: true

module OktaVdc
  class Client
    AUTH_TOKEN_CACHE_KEY = :okta_vdc_api_auth_token
    AUTH_TOKEN_PREEMPTIVE_EXPIRY = 1.minute.freeze
    DEFAULT_AUTH_URL = 'https://vdc-beta-program.eu.auth0.com'

    class RequestError < StandardError; end

    def create_credential_request(response_mode: 'dc_api.jwt', expected_origin: '')
      body = {
        response_mode: response_mode,
        protocol: 'openid4vp-v1-signed',
        expected_origin: expected_origin.presence,
        dcql_query: DcqlQueryBuilder.build,
      }.compact

      response = api_faraday.post('/v1/verify/initiate', body)
      response.body
    end

    def get_request_status(session_id:)
      response = api_faraday.get("/v1/verify/sessions/#{session_id}/status")
      response.body
    end

    def get_claims(session_id:, authorization_response:)
      response = api_faraday.post(
        "/v1/verify/sessions/#{session_id}/claims",
        {
          authorization_response: {
            response: authorization_response,
          },
        },
      )
      response.body
    end

    private

    def retrieve_token!
      response = oauth_faraday.post("#{oauth_domain}/oauth/token") do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = {
          client_id: IdentityConfig.store.okta_vdc_client_id,
          client_secret: IdentityConfig.store.okta_vdc_client_secret,
          audience: base_url,
          grant_type: 'client_credentials',
        }.to_json
      end

      body = response.body
      expires_in = body['expires_in'].to_i.seconds
      expires_in -= AUTH_TOKEN_PREEMPTIVE_EXPIRY if expires_in > AUTH_TOKEN_PREEMPTIVE_EXPIRY
      token = "#{body['token_type']} #{body['access_token']}"
      Rails.cache.write(AUTH_TOKEN_CACHE_KEY, token, expires_in: expires_in)
      token
    end

    def token
      Rails.cache.read(AUTH_TOKEN_CACHE_KEY) || retrieve_token!
    end

    def api_faraday
      Faraday.new(url: base_url, headers: api_headers) do |conn|
        conn.options.timeout = IdentityConfig.store.okta_vdc_request_timeout
        conn.request :instrumentation, name: 'request_log.faraday'
        conn.request :json
        conn.response :raise_error
        conn.response :json
      end
    end

    def oauth_faraday
      Faraday.new do |conn|
        conn.options.timeout = IdentityConfig.store.okta_vdc_request_timeout
        conn.request :instrumentation, name: 'request_log.faraday'
        conn.response :raise_error
        conn.response :json
      end
    end

    def api_headers
      {
        'Authorization' => token,
        'Content-Type' => 'application/json',
      }
    end

    def base_url
      IdentityConfig.store.okta_vdc_base_url
    end

    def oauth_domain
      IdentityConfig.store.okta_vdc_oauth_domain.presence || DEFAULT_AUTH_URL
    end
  end
end
