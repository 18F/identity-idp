require 'rails_helper'

RSpec.describe OpenidConnectConfigurationPresenter do
  include Rails.application.routes.url_helpers

  subject(:presenter) { OpenidConnectConfigurationPresenter.new }

  describe '#configuration' do
    subject(:configuration) { presenter.configuration }

    before do
      allow(IdentityConfig.store).to receive(:token_exchange_enabled)
        .and_return(token_exchange_enabled)
    end

    # Exactly the document Login.gov publishes with delegated access switched off; a change to
    # this list is a change partners see, so a new member needs a reason.
    let(:baseline) do
      {
        acr_values_supported: Saml::Idp::Constants::VALID_AUTHN_CONTEXTS,
        claims_supported: OpenidConnectAttributeScoper::UNSCOPED_CLAIMS +
          OpenidConnectAttributeScoper::CLAIMS,
        grant_types_supported: %w[authorization_code],
        response_types_supported: %w[code],
        scopes_supported: OpenidConnectAttributeScoper::VALID_SCOPES,
        subject_types_supported: %w[pairwise],
        authorization_endpoint: openid_connect_authorize_url,
        issuer: root_url,
        jwks_uri: api_openid_connect_certs_url,
        service_documentation: 'https://developers.login.gov/',
        token_endpoint: api_openid_connect_token_url,
        userinfo_endpoint: api_openid_connect_userinfo_url,
        end_session_endpoint: openid_connect_logout_url,
        id_token_signing_alg_values_supported: %w[RS256],
        token_endpoint_auth_methods_supported: %w[private_key_jwt],
        token_endpoint_auth_signing_alg_values_supported: %w[RS256],
      }
    end

    context 'with delegated access switched off' do
      let(:token_exchange_enabled) { false }

      it 'is exactly the document published before delegated access, member for member' do
        expect(configuration).to eq(baseline)
        expect(configuration.keys).to eq(baseline.keys)
      end

      it 'advertises none of the delegated-access metadata' do
        expect(configuration.keys).not_to include(
          :introspection_endpoint,
          :introspection_endpoint_auth_methods_supported,
          :introspection_endpoint_auth_signing_alg_values_supported,
          :revocation_endpoint,
          :revocation_endpoint_auth_methods_supported,
          :revocation_endpoint_auth_signing_alg_values_supported,
          :dpop_signing_alg_values_supported,
        )
        expect(configuration[:grant_types_supported]).to eq(%w[authorization_code])
        expect(configuration[:token_endpoint_auth_methods_supported]).to eq(%w[private_key_jwt])
      end
    end

    context 'with delegated access switched on' do
      let(:token_exchange_enabled) { true }

      it 'keeps every member of the baseline document except the two it extends' do
        unchanged = baseline.except(
          :grant_types_supported, :token_endpoint_auth_methods_supported
        )
        expect(configuration).to include(unchanged)
      end

      it 'adds the token-exchange and refresh grants at the existing token endpoint' do
        expect(configuration[:grant_types_supported]).to eq(
          %w[authorization_code refresh_token urn:ietf:params:oauth:grant-type:token-exchange],
        )
        expect(configuration).not_to have_key(:token_exchange_endpoint)
      end

      it 'lists none as a token endpoint authentication method for public clients' do
        expect(configuration[:token_endpoint_auth_methods_supported])
          .to eq(%w[private_key_jwt none])
      end

      it 'advertises the introspection endpoint with its authentication members' do
        expect(configuration[:introspection_endpoint]).to eq(api_openid_connect_introspect_url)
        expect(configuration[:introspection_endpoint_auth_methods_supported])
          .to eq(%w[private_key_jwt none])
        expect(configuration[:introspection_endpoint_auth_signing_alg_values_supported])
          .to eq(%w[RS256])
      end

      it 'advertises the revocation endpoint with its authentication members' do
        expect(configuration[:revocation_endpoint]).to eq(api_openid_connect_revoke_url)
        expect(configuration[:revocation_endpoint_auth_methods_supported])
          .to eq(%w[private_key_jwt none])
        expect(configuration[:revocation_endpoint_auth_signing_alg_values_supported])
          .to eq(%w[RS256])
      end

      it 'advertises the DPoP proof algorithms' do
        expect(configuration[:dpop_signing_alg_values_supported]).to eq(%w[ES256 RS256])
      end

      it 'does not enumerate per-partner delegation scopes' do
        expect(configuration[:scopes_supported]).to eq(OpenidConnectAttributeScoper::VALID_SCOPES)
        expect(configuration[:scopes_supported].grep(/token_exchange/)).to be_empty
      end
    end
  end
end
