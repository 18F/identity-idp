# frozen_string_literal: true

# The OpenID Connect Discovery 1.0 document served at /.well-known/openid-configuration.
#
# The delegated-access metadata (RFC 8414 §2 member names) is advertised only while delegated
# access is switched on, so the document never names a grant type the token endpoint answers with
# `unsupported_grant_type` or an endpoint that is not found. With the switch off the document is
# exactly what Login.gov has always published.
class OpenidConnectConfigurationPresenter
  include Rails.application.routes.url_helpers

  def configuration
    {
      acr_values_supported: Saml::Idp::Constants::VALID_AUTHN_CONTEXTS,
      claims_supported: claims_supported,
      grant_types_supported: grant_types_supported,
      response_types_supported: %w[code],
      scopes_supported: OpenidConnectAttributeScoper::VALID_SCOPES,
      subject_types_supported: %w[pairwise],
    }.merge(url_configuration).merge(crypto_configuration).merge(delegated_access_configuration)
  end

  def url_options
    {}
  end

  private

  def url_configuration
    {
      authorization_endpoint: openid_connect_authorize_url,
      issuer: root_url,
      jwks_uri: api_openid_connect_certs_url,
      service_documentation: 'https://developers.login.gov/',
      token_endpoint: api_openid_connect_token_url,
      userinfo_endpoint: api_openid_connect_userinfo_url,
      end_session_endpoint: openid_connect_logout_url,
    }
  end

  # `none` (RFC 8414 §2, RFC 7591 §2) is listed only with delegated access on: a public client
  # identifies itself with `client_id` alone and binds its tokens to a key instead, which the
  # token endpoint accepts only for the delegated-access grants.
  #
  # The userinfo encryption members (OpenID Connect Discovery 1.0 §3) name the one JWE algorithm
  # pair a service provider may opt in to; they are advertised unconditionally because the opt-in
  # is per record and does not depend on delegated access.
  def crypto_configuration
    {
      id_token_signing_alg_values_supported: %w[RS256],
      token_endpoint_auth_methods_supported: token_endpoint_auth_methods_supported,
      token_endpoint_auth_signing_alg_values_supported: %w[RS256],
      userinfo_encryption_alg_values_supported: [OpenidConnect::UserInfoEncryptor::ALG],
      userinfo_encryption_enc_values_supported: [OpenidConnect::UserInfoEncryptor::ENC],
    }
  end

  # RFC 8693 token exchange and the RFC 6749 §6 refresh grant are served at the token endpoint,
  # which is already advertised; RFC 8693 defines no endpoint of its own.
  def grant_types_supported
    return %w[authorization_code] unless delegated_access_enabled?

    %W[authorization_code refresh_token #{OpenidConnectTokenExchangeForm::GRANT_TYPE}]
  end

  def token_endpoint_auth_methods_supported
    return %w[private_key_jwt] unless delegated_access_enabled?

    %w[private_key_jwt none]
  end

  # RFC 8414 §2 members for the RFC 7662 introspection and RFC 7009 revocation endpoints, and the
  # RFC 9449 §5.1 list of proof algorithms. Introspection is for agency APIs with `private_key_jwt`
  # and for the public-client service provider asking about its own token with a DPoP proof;
  # revocation likewise serves both client types. `token_exchange:*` scope values are per partner
  # and are not enumerated in `scopes_supported`.
  def delegated_access_configuration
    return {} unless delegated_access_enabled?

    {
      introspection_endpoint: api_openid_connect_introspect_url,
      introspection_endpoint_auth_methods_supported: %w[private_key_jwt none],
      introspection_endpoint_auth_signing_alg_values_supported: %w[RS256],
      revocation_endpoint: api_openid_connect_revoke_url,
      revocation_endpoint_auth_methods_supported: %w[private_key_jwt none],
      revocation_endpoint_auth_signing_alg_values_supported: %w[RS256],
      dpop_signing_alg_values_supported: DpopProofVerifier::ALLOWED_ALGORITHMS,
    }
  end

  def delegated_access_enabled?
    IdentityConfig.store.token_exchange_enabled
  end

  def claims_supported
    OpenidConnectAttributeScoper::UNSCOPED_CLAIMS + OpenidConnectAttributeScoper::CLAIMS
  end
end
