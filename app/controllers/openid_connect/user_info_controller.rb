# frozen_string_literal: true

module OpenidConnect
  class UserInfoController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token
    before_action :authenticate_identity_via_bearer_token

    attr_reader :current_identity

    # The claims are released as plain JSON unless the service provider is configured for
    # encrypted responses (OpenID Connect Core 1.0 §5.3.2), in which case the same claims, exactly
    # what the presenter released for the granted scopes, are served as one compact JWE with the
    # content type `application/jwt`. The presenter is not told about encryption, so an encrypted
    # response carries precisely the claims a plain one would.
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

    # Fails closed: when the configured record has no usable key, the request is refused with
    # `server_error` (the RFC 6749 §4.1.2.1 vocabulary) and the claims are never written to the
    # response in the clear. The refusal is logged so the record can be repaired.
    def render_encrypted_user_info(user_info)
      jwe = OpenidConnect::JweEncryptor.encrypt(user_info.to_json, service_provider:)
      render plain: jwe, content_type: 'application/jwt'
    rescue OpenidConnect::JweEncryptor::NoUsableKeyError, OpenSSL::OpenSSLError => e
      analytics.openid_connect_userinfo_encryption_failed(
        client_id: service_provider.issuer,
        error: e.class.name,
      )
      render json: {
        error: 'server_error',
        error_description: t('openid_connect.user_info.errors.encryption_unavailable'),
      }, status: :internal_server_error
    end

    def authenticate_identity_via_bearer_token
      verifier = AccessTokenVerifier.new(request.env['HTTP_AUTHORIZATION'])
      response, identity = verifier.submit
      attributes = response.to_h
      analytics.openid_connect_bearer_token(
        **attributes.except(:integration_errors),
        encrypted: identity&.service_provider_record&.userinfo_encrypted_response?,
      )

      if response.success?
        @current_identity = identity
      else
        analytics.sp_integration_errors_present(**attributes[:integration_errors])
        render json: { error: verifier.errors[:access_token].join(' ') },
               status: :unauthorized
      end
    end
  end
end
