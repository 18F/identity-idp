require 'rails_helper'

RSpec.describe OpenidConnectConfigurationPresenter do
  include Rails.application.routes.url_helpers

  subject(:presenter) { OpenidConnectConfigurationPresenter.new }

  describe '#configuration' do
    subject(:configuration) { presenter.configuration }

    it 'includes information about the OpenID Connect integration' do
      aggregate_failures do
        expect(configuration[:issuer]).to eq(root_url)
        expect(configuration[:authorization_endpoint]).to eq(openid_connect_authorize_url)
        expect(configuration[:token_endpoint]).to eq(api_openid_connect_token_url)
        expect(configuration[:userinfo_endpoint]).to eq(api_openid_connect_userinfo_url)
        expect(configuration[:end_session_endpoint]).to eq(openid_connect_logout_url)
        expect(configuration[:jwks_uri]).to eq(api_openid_connect_certs_url)
        expect(configuration[:service_documentation]).to eq('https://pages.18f.gov/identity-dev-docs/')
        expect(configuration[:response_types_supported]).to eq(%w[code])
        expect(configuration[:grant_types_supported]).to eq(%w[authorization_code])
        expect(configuration[:acr_values_supported]).
          to match_array(Saml::Idp::Constants::VALID_AUTHN_CONTEXTS)
        expect(configuration[:subject_types_supported]).to eq(%w[pairwise])
        expect(configuration[:id_token_signing_alg_values_supported]).to eq(%w[RS256])
        expect(configuration[:token_endpoint_auth_methods_supported]).to eq(%w[private_key_jwt])
        expect(configuration[:token_endpoint_auth_signing_alg_values_supported]).to eq(%w[RS256])

        claims = %w[iss sub] + OpenidConnectAttributeScoper::CLAIMS
        expect(configuration[:claims_supported]).to match_array(claims)
      end
    end
  end
end
