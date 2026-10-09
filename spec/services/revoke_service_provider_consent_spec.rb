require 'rails_helper'

RSpec.describe RevokeServiceProviderConsent do
  let(:now) { Time.zone.now }

  subject(:service) { RevokeServiceProviderConsent.new(identity, now: now) }

  describe '#call' do
    let!(:identity) do
      create(:service_provider_identity, deleted_at: nil, verified_attributes: ['email'])
    end

    it 'sets the deleted_at' do
      expect { service.call }
        .to change { identity.reload.deleted_at&.to_i }
        .from(nil).to(now.to_i)
    end

    it 'clears the verified attributes' do
      expect { service.call }
        .to change { identity.reload.verified_attributes }
        .from(['email']).to(nil)
    end

    it 'ends every delegated-access approval the person gave that service provider' do
      allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
      identity.update!(user: create(:user, :fully_registered))
      service_provider = ServiceProvider.find_by(issuer: identity.service_provider) ||
                         create(:service_provider, issuer: identity.service_provider)
      service_provider.update!(token_exchange_enabled_sp: true, active: true)
      application = create(:service_provider, :delegation_application)
      grant = TokenExchangeGrant.approve!(
        user: identity.user, service_provider:, application:,
        source: 'account_page', remember: true
      )
      other_sp_grant = TokenExchangeGrant.approve!(
        user: identity.user,
        service_provider: create(:service_provider, :delegation_service_provider),
        application:, source: 'account_page', remember: true
      )

      service.call

      expect(grant.reload.revoked_at.to_i).to eq(now.to_i)
      expect(grant.revocation_reason).to eq('sp_disconnected')
      expect(other_sp_grant.reload.revoked_at).to be_nil
    end
  end
end
