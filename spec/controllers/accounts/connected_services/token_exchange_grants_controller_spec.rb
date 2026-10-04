require 'rails_helper'

RSpec.describe Accounts::ConnectedServices::TokenExchangeGrantsController do
  let(:user) { create(:user, :fully_registered) }
  let(:broker) { create(:service_provider, :active, issuer: 'broker.gov') }
  let(:target) do
    create(
      :service_provider, :active, issuer: 'target.gov',
                                  allowed_token_exchange_brokers: ['broker.gov']
    )
  end
  let!(:broker_identity) do
    create(:service_provider_identity, user: user, service_provider: broker.issuer)
  end
  let!(:target_identity) do
    create(:service_provider_identity, user: user, service_provider: target.issuer)
  end

  before do
    stub_analytics
    stub_sign_in(user)
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:token_exchange_service_providers)
      .and_return(['broker.gov'])
  end

  def grant
    TokenExchangeGrant.active.find_by(
      user: user, broker_issuer: 'broker.gov',
      target_issuer: 'target.gov'
    )
  end

  describe '#update (target)' do
    it 'enables a per-application grant and redirects back to the broker card' do
      patch :update, params: {
        identity_id: broker_identity.id,
        grant_type: 'target',
        target_issuer: 'target.gov',
        enabled: '1',
      }

      expect(response).to redirect_to(
        account_connected_services_path(anchor: "connected-app-#{broker_identity.id}"),
      )
      expect(grant).to be_present
      expect(@analytics).to have_logged_event(
        :token_exchange_grant_toggled,
        issuer: 'broker.gov', target_issuer: 'target.gov', enabled: true,
      )
    end

    it 'disables (revokes) a per-application grant' do
      TokenExchangeGrant.grant_one!(
        user: user, broker_issuer: 'broker.gov',
        target_issuer: 'target.gov'
      )

      patch :update, params: {
        identity_id: broker_identity.id,
        grant_type: 'target',
        target_issuer: 'target.gov',
        enabled: '0',
      }

      expect(grant).to be_nil
      expect(
        TokenExchangeGrant.find_by(
          user: user,
          target_issuer: 'target.gov',
        ).revoked_at,
      ).to be_present
    end

    it 'refuses a target that has not opted in to the broker' do
      target.update!(allowed_token_exchange_brokers: [])
      patch :update, params: {
        identity_id: broker_identity.id,
        grant_type: 'target',
        target_issuer: 'target.gov',
        enabled: '1',
      }
      expect(response).to have_http_status(:not_found)
      expect(grant).to be_nil
    end

    it 'refuses a target the user has not linked' do
      target_identity.destroy!
      patch :update, params: {
        identity_id: broker_identity.id,
        grant_type: 'target',
        target_issuer: 'target.gov',
        enabled: '1',
      }
      expect(response).to have_http_status(:not_found)
    end

    it 'refuses when the identity is not an allow-listed broker' do
      allow(IdentityConfig.store).to receive(:token_exchange_service_providers).and_return([])
      patch :update, params: {
        identity_id: broker_identity.id,
        grant_type: 'target',
        target_issuer: 'target.gov',
        enabled: '1',
      }
      expect(response).to have_http_status(:not_found)
    end

    it 'refuses granting the broker to itself' do
      broker.update!(allowed_token_exchange_brokers: ['broker.gov'])
      patch :update, params: {
        identity_id: broker_identity.id,
        grant_type: 'target',
        target_issuer: 'broker.gov',
        enabled: '1',
      }
      expect(response).to have_http_status(:not_found)
    end

    it "refuses another user's identity" do
      other = create(
        :service_provider_identity, user: create(:user),
                                    service_provider: broker.issuer
      )
      patch :update, params: {
        identity_id: other.id, grant_type: 'target', target_issuer: 'target.gov', enabled: '1'
      }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe '#update (auto_enroll)' do
    it 'enables auto-enrollment, stamping the consent time' do
      freeze_time do
        patch :update,
              params: { identity_id: broker_identity.id, grant_type: 'auto_enroll', enabled: '1' }

        setting = TokenExchangeBrokerSetting.find_by(user: user, broker_issuer: 'broker.gov')
        expect(setting.auto_enroll_enabled?).to eq(true)
        expect(setting.auto_enroll_granted_at).to eq(Time.zone.now)
      end
      expect(@analytics).to have_logged_event(
        :token_exchange_auto_enroll_toggled, issuer: 'broker.gov', enabled: true
      )
    end

    it 'disables auto-enrollment' do
      TokenExchangeBrokerSetting.for(user: user, broker_issuer: 'broker.gov').enable_auto_enroll!
      patch :update,
            params: { identity_id: broker_identity.id, grant_type: 'auto_enroll', enabled: '0' }

      expect(
        TokenExchangeBrokerSetting.find_by(
          user: user,
          broker_issuer: 'broker.gov',
        ).auto_enroll_enabled?,
      )
        .to eq(false)
    end
  end

  it 'rejects an unknown grant_type' do
    patch :update, params: { identity_id: broker_identity.id, grant_type: 'bogus', enabled: '1' }
    expect(response).to have_http_status(:not_found)
  end
end
