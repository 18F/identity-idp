# frozen_string_literal: true

module OpenidConnect
  class UserInfoController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token
    before_action :authenticate_identity_via_bearer_token

    attr_reader :current_identity

    # The claims are released as plain JSON unless the service provider has opted in to encrypted
    # responses (OpenID Connect Core 1.0 §5.3.2), in which case the same claims, whatever the
    # presenter released for the granted scopes, are served as one compact JWE with content type
    # `application/jwt`. The presenter is not told about encryption, so an opted-in service
    # provider receives exactly the claims a plain response would carry.
    def show
      user_info = OpenidConnectUserInfoPresenter.new(current_identity).user_info

      if service_provider&.userinfo_encrypted_response?
        render_encrypted_user_info(user_info)
      else
        render json: user_info
      end
    end

    private

    def service_provider
      current_identity.service_provider_record
    end

    # Fails closed: when the opted-in record has no usable key the request is refused with a
    # `server_error` (RFC 6749 §4.1.2.1 vocabulary) and the claims are never written to the
    # response in the clear. The refusal is logged so the misconfigured record can be repaired.
    def render_encrypted_user_info(user_info)
      jwe = UserInfoEncryptor.new(service_provider:, claims: user_info).call
      render plain: jwe, content_type: 'application/jwt'
    rescue UserInfoEncryptor::NoUsableKeyError, OpenSSL::OpenSSLError => e
      analytics.openid_connect_userinfo_encryption_failed(
        client_id: service_provider.issuer,
        error: e.class.name,
      )
      render json: {
        error: 'server_error',
        error_description: t('openid_connect.user_info.errors.encryption_unavailable'),
      }, status: :internal_server_error
    end

    # The access token arrives under the Bearer scheme, or under the DPoP scheme with a proof in
    # the `DPoP` header when it is bound to the client's key (RFC 9449 §7.1); the proof must name
    # this method and URL.
    def authenticate_identity_via_bearer_token
      verifier = AccessTokenVerifier.new(
        request.env['HTTP_AUTHORIZATION'],
        dpop_proof: request.headers['DPoP'].presence,
        http_method: request.request_method,
        http_url: api_openid_connect_userinfo_url,
      )
      result, identity = verifier.submit
      attributes = result.to_h
      analytics.openid_connect_bearer_token(
        **attributes.except(:integration_errors),
        encrypted: identity&.service_provider_record&.userinfo_encrypted_response?,
      )

      if result.success?
        @current_identity = identity
      else
        analytics.sp_integration_errors_present(**attributes[:integration_errors])
        challenge = verifier.www_authenticate
        response.headers['WWW-Authenticate'] = challenge if challenge
        render json: { error: verifier.errors[:access_token].join(' ') },
               status: :unauthorized
      end
    end
  end
end
