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

    it 'revokes the token exchange refresh tokens the service provider holds for the person' do
      user = create(:user)
      identity.update!(user:)
      refresh_token = create(
        :token_exchange_refresh_token, user:, actor_issuer: identity.service_provider
      )

      service.call

      expect(refresh_token.reload.revocation_reason).to eq('service_provider_disconnected')
    end

    it 'clears the verified attributes' do
      expect { service.call }
        .to change { identity.reload.verified_attributes }
        .from(['email']).to(nil)
    end
  end
end
