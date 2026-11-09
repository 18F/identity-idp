require 'rails_helper'

RSpec.describe TokenExchange::RefreshTokenRevoker do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let!(:records_family) do
    create(:token_exchange_refresh_token, user:, resource: 'https://records.example.gov')
  end
  let!(:passport_family) do
    create(
      :token_exchange_refresh_token,
      user:, actor_issuer: 'other-actor', resource: 'https://passport.example.gov',
    )
  end
  let!(:other_users_family) { create(:token_exchange_refresh_token, user: other_user) }

  describe '.revoke_for_security_event' do
    it 'revokes all of the person’s families after a password reset' do
      described_class.revoke_for_security_event(PushNotification::PasswordResetEvent.new(user:))

      expect(records_family.reload.revocation_reason).to eq('security_event')
      expect(passport_family.reload).to be_revoked
      expect(other_users_family.reload).not_to be_revoked
    end

    it 'revokes nothing for an event that does not end delegated access' do
      described_class.revoke_for_security_event(PushNotification::AccountEnabledEvent.new(user:))

      expect(records_family.reload).not_to be_revoked
    end
  end

  describe '.revoke_for_actor' do
    it 'revokes only that actor’s families for the person' do
      described_class.revoke_for_actor(user_id: user.id, actor_issuer: 'other-actor')

      expect(passport_family.reload.revocation_reason).to eq('service_provider_disconnected')
      expect(records_family.reload).not_to be_revoked
    end
  end

  describe '.revoke_for_target' do
    before do
      allow(IdentityConfig.store).to receive(:token_exchange_allowed_targets).and_return(
        [{ issuer: 'records-issuer', resource: 'https://records.example.gov' },
         { issuer: 'passport-issuer', resource: 'https://passport.example.gov' }],
      )
    end

    it 'revokes only the families whose sign-in named a resource of that target' do
      described_class.revoke_for_target(user:, target_app: 'records-issuer')

      expect(records_family.reload.revocation_reason).to eq('consent_revoked')
      expect(passport_family.reload).not_to be_revoked
    end

    it 'revokes nothing for a target that is not configured' do
      expect(described_class.revoke_for_target(user:, target_app: 'unknown')).to eq(0)
    end
  end
end
