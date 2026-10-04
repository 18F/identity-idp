require 'rails_helper'

RSpec.describe OpenidConnect::ExchangeController do
  describe '#create' do
    subject(:action) do
      post :create,
           params: {
             grant_type: OpenidConnectTokenExchangeForm::TOKEN_EXCHANGE_GRANT_TYPE,
             subject_token: subject_token,
             subject_token_type: OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE,
             audience: 'target.gov',
           }
    end

    let(:user) { create(:user, :proofed) }
    let(:rails_session_id) { SecureRandom.uuid }
    let!(:broker_sp) { create(:service_provider, :active, issuer: 'broker.gov') }
    let!(:target_sp) do
      create(
        :service_provider, :active,
        issuer: 'target.gov',
        ial: 2,
        attribute_bundle: %w[email],
        allowed_token_exchange_brokers: ['broker.gov']
      )
    end
    let!(:broker_identity) do
      create(
        :service_provider_identity,
        user: user,
        service_provider: 'broker.gov',
        access_token: SecureRandom.urlsafe_base64,
        rails_session_id: rails_session_id,
        ial: 2,
        verified_attributes: %w[email],
        scope: 'openid email token_exchange',
      )
    end
    let(:subject_token) { broker_identity.access_token }
    let(:grant_targets) { ['target.gov'] }

    before do
      allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:token_exchange_service_providers)
        .and_return(['broker.gov'])
      OutOfBandSessionAccessor.new(rails_session_id).put_empty_user_session
      if grant_targets
        TokenExchangeGrant.grant!(user: user, broker_issuer: 'broker.gov', targets: grant_targets)
      end
    end

    it 'returns a target access token' do
      action

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['access_token']).to be_present
      expect(body['exchanged_from']).to eq('broker.gov')
    end

    context 'when audience is not allowlisted' do
      before do
        target_sp.update!(allowed_token_exchange_brokers: [])
      end

      it 'returns bad_request' do
        action
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when the user never granted token-exchange consent' do
      let(:grant_targets) { nil }

      it 'returns invalid_request (RFC 8693 §2.2.2) and mints nothing' do
        action
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('invalid_request')
        expect(user.identities.find_by(service_provider: 'target.gov')).to be_nil
      end
    end
  end
end
