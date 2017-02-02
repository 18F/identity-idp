require 'rails_helper'

RSpec.describe OpenidConnect::ConfigurationController do
  describe '#index' do
    let(:json_response) { JSON.parse(response.body).with_indifferent_access }

    it 'renders information about the OpenID Connect integration' do
      get :index

      aggregate_failures do
        expect(json_response[:issuer]).to eq(root_url)
        expect(json_response[:authorization_endpoint]).to eq(openid_connect_authorize_url)
        expect(json_response[:token_endpoint]).to eq(openid_connect_token_url)
        expect(json_response[:userinfo_endpoint]).to eq(openid_connect_userinfo_url)
        expect(json_response[:response_types_supported]).to eq(%w(code))
        expect(json_response[:grant_types_supported]).to eq(%w(authorization_code))
        expect(json_response[:acr_values_supported]).
          to match_array(Saml::Idp::Constants::VALID_AUTHN_CONTEXTS)
        expect(json_response[:subject_types_supported]).to eq(%w(pairwise))
        expect(json_response[:id_token_signing_alg_values_supported]).to eq(%w(RS256))
        expect(json_response[:token_endpoint_auth_methods_supported]).to eq(%w(client_secret_post))
        expect(json_response[:token_endpoint_auth_signing_alg_values_supported]).to eq(%w(RS256))

        claims = %w(iss sub) + OpenidConnectAttributeScoper::CLAIMS
        expect(json_response[:claims_supported]).to match_array(claims)
      end
    end

    it 'renders all keys' do
      get :index

      pending 'additional details'

      aggregate_failures do
        expect(json_response[:jwks_uri]).to be_present
        expect(json_response[:service_documentation]).to be_present
      end
    end
  end
end
