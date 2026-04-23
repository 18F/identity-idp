# frozen_string_literal: true

module Mattr
  class VerifierClient
    AUTH_TOKEN_CACHE_KEY = :mattr_verifier_api_auth_token
    AUTH_TOKEN_PREEMPTIVE_EXPIRY = 1.minute.freeze

    class RequestError < StandardError; end

    def get_presentation_result(session_id:)
      response = api_faraday.get("/v2/presentations/sessions/#{session_id}/result")
      response.body
    end

    def create_application(
      name:,
      domain:,
      redirect_uris:,
      display: {},
      result_in_front_channel: false
    )
      body = {
        name: name,
        type: 'web',
        domain: domain,
        openid4vpConfiguration: {
          supportedModes: 'all',
          redirectUris: Array(redirect_uris),
          display: display,
        }.compact,
        resultAvailableInFrontChannel: result_in_front_channel,
      }

      response = api_faraday.post('/v2/presentations/applications', body)
      response.body
    end

    def list_applications
      response = api_faraday.get('/v2/presentations/applications')
      response.body
    end

    def create_wallet_provider(name:, authorization_endpoint:)
      body = {
        name: name,
        openid4vpConfiguration: {
          authorizationEndpoint: authorization_endpoint,
        },
      }

      response = api_faraday.post('/v2/presentations/wallet-providers', body)
      response.body
    end

    def list_wallet_providers
      response = api_faraday.get('/v2/presentations/wallet-providers')
      response.body
    end

    def add_trusted_issuer(certificate_pem:)
      response = api_faraday.post(
        '/v2/credentials/mobile/trusted-issuers',
        { certificatePem: certificate_pem },
      )
      response.body
    end

    def list_trusted_issuers
      response = api_faraday.get('/v2/credentials/mobile/trusted-issuers')
      response.body
    end

    private

    def retrieve_token!
      response = oauth_faraday.post("#{auth_url}/oauth/token") do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = {
          client_id: IdentityConfig.store.mattr_client_id,
          client_secret: IdentityConfig.store.mattr_client_secret,
          audience: audience,
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
      Faraday.new(url: tenant_url, headers: api_headers) do |conn|
        conn.options.timeout = IdentityConfig.store.mattr_request_timeout
        conn.request :instrumentation, name: 'request_log.faraday'
        conn.request :json
        conn.response :raise_error
        conn.response :json
      end
    end

    def oauth_faraday
      Faraday.new do |conn|
        conn.options.timeout = IdentityConfig.store.mattr_request_timeout
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

    def tenant_url
      IdentityConfig.store.mattr_tenant_url
    end

    def auth_url
      IdentityConfig.store.mattr_auth_url
    end

    def audience
      IdentityConfig.store.mattr_audience.presence || tenant_url
    end
  end
end
