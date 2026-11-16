require 'rails_helper'

RSpec.describe OpenidConnect::TokenRevocationController do
  describe '#create' do
    let(:actor) { create(:service_provider, :active) }
    let!(:refresh_token) do
      create(:token_exchange_refresh_token, actor_issuer: actor.issuer, token: 'the-token')
    end

    before do
      allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers)
        .and_return([actor.issuer])
    end

    it 'revokes the refresh token family and logs the revocation' do
      stub_analytics

      post :create, params: { client_id: actor.issuer, token: 'the-token' }

      expect(response).to be_ok
      expect(refresh_token.reload).to be_revoked
      expect(@analytics).to have_logged_event(
        :openid_connect_token_revocation,
        success: true,
        client_id: actor.issuer,
        revoked: true,
        refresh_token_family_id: refresh_token.family_id,
      )
    end

    it 'answers an unknown client with invalid_client' do
      post :create, params: { client_id: 'unknown', token: 'the-token' }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)).to eq('error' => 'invalid_client')
    end
  end
end
