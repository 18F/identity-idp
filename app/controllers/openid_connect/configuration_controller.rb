module OpenidConnect
  class ConfigurationController < ApplicationController
    def index
      render json: {
        jwks_uri: '', # TODO
        scopes_supported: OpenidConnectAttributeScoper::VALID_SCOPES,
        response_types_supported: %w(code),
        grant_types_supported: %w(authorization_code),
        acr_values_supported: Saml::Idp::Constants::VALID_AUTHN_CONTEXTS,
        subject_types_supported: %w(pairwise),
        service_documentation: '', # TODO
        claims_supported: claims_supported
      }.merge(url_configuration).merge(crypto_configuration)
    end

    private

    def url_configuration
      {
        issuer: root_url,
        authorization_endpoint: openid_connect_authorize_url,
        token_endpoint: openid_connect_token_url,
        userinfo_endpoint: openid_connect_userinfo_url
      }
    end

    def crypto_configuration
      {
        id_token_signing_alg_values_supported: %w(RS256),
        token_endpoint_auth_methods_supported: %w(private_key_jwt),
        token_endpoint_auth_signing_alg_values_supported: %w(RS256)
      }
    end

    def claims_supported
      %w(iss sub) + OpenidConnectAttributeScoper::CLAIMS
    end
  end
end
