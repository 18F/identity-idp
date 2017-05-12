class OpenidConnectConfigurationPresenter
  include Rails.application.routes.url_helpers

  def configuration
    {
      acr_values_supported: Saml::Idp::Constants::VALID_AUTHN_CONTEXTS,
      claims_supported: claims_supported,
      grant_types_supported: %w[authorization_code],
      response_types_supported: %w[code],
      scopes_supported: OpenidConnectAttributeScoper::VALID_SCOPES,
      subject_types_supported: %w[pairwise],
    }.merge(url_configuration).merge(crypto_configuration)
  end

  private

  def url_configuration
    {
      authorization_endpoint: openid_connect_authorize_url,
      issuer: root_url,
      jwks_uri: api_openid_connect_certs_url,
      service_documentation: 'https://pages.18f.gov/identity-dev-docs/',
      token_endpoint: api_openid_connect_token_url,
      userinfo_endpoint: api_openid_connect_userinfo_url,
      end_session_endpoint: openid_connect_logout_url,
    }
  end

  def crypto_configuration
    {
      id_token_signing_alg_values_supported: %w[RS256],
      token_endpoint_auth_methods_supported: %w[private_key_jwt],
      token_endpoint_auth_signing_alg_values_supported: %w[RS256],
    }
  end

  def claims_supported
    %w[iss sub] + OpenidConnectAttributeScoper::CLAIMS
  end
end
