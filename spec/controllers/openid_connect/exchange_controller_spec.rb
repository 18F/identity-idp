require 'rails_helper'

RSpec.describe OpenidConnect::ExchangeController do
  describe '#create' do
    subject(:action) do
      post :create,
           params: {
             grant_type: OpenidConnectTokenExchangeForm::TOKEN_EXCHANGE_GRANT_TYPE,
             subject_token: subject_token,
             subject_token_type: OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE,
             audience: 'urn:application',
           }
    end

    let(:user) { create(:user, :proofed) }
    let(:rails_session_id) { SecureRandom.uuid }
    let!(:delegating_sp) do
      create(:service_provider, :active, issuer: 'urn:mybenefits', token_exchange_enabled_sp: true)
    end
    let!(:application_sp) do
      create(
        :service_provider, :active,
        issuer: 'urn:application',
        ial: 2,
        attribute_bundle: %w[email],
        delegation_application: true, allowed_delegation_service_providers: ['urn:mybenefits']
      )
    end
    let!(:delegating_identity) do
      create(
        :service_provider_identity,
        user: user,
        service_provider: 'urn:mybenefits',
        access_token: SecureRandom.urlsafe_base64,
        rails_session_id: rails_session_id,
        ial: 2,
        verified_attributes: %w[email],
        scope: 'openid email token_exchange:application',
      )
    end
    let(:subject_token) { delegating_identity.access_token }
    let(:approved_applications) { ['urn:application'] }

    before do
      allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
      OutOfBandSessionAccessor.new(rails_session_id).put_empty_user_session
      Array(approved_applications).each do |issuer|
        TokenExchangeGrant.approve!(
          user: user, service_provider: delegating_sp,
          application: ServiceProvider.find_by!(issuer: issuer),
          source: 'consent_screen', remember: true
        )
      end
    end

    it 'returns a application access token' do
      action

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['access_token']).to be_present
      expect(body['exchanged_from']).to eq('urn:mybenefits')
    end

    context 'when audience is not allowlisted' do
      before do
        application_sp.update!(allowed_delegation_service_providers: ['other-service-provider.gov'])
      end

      it 'returns bad_request' do
        action
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when the user never granted token-exchange consent' do
      let(:approved_applications) { nil }

      it 'returns invalid_request (RFC 8693 §2.2.2) and mints nothing' do
        action
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('invalid_request')
        expect(user.identities.find_by(service_provider: 'urn:application')).to be_nil
      end
    end
  end
end
