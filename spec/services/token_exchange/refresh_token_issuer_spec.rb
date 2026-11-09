require 'rails_helper'

RSpec.describe TokenExchange::RefreshTokenIssuer do
  let(:now) { Time.zone.now.change(usec: 0) }
  let(:user) { create(:user) }
  let(:service_provider) { create(:service_provider) }
  let(:identity) do
    create(
      :service_provider_identity,
      user:,
      service_provider: service_provider.issuer,
      scope: 'openid token_exchange',
      ial: 1,
    )
  end
  let(:resource) { 'https://records.example.gov' }
  let(:dpop_jkt) { SecureRandom.urlsafe_base64(32) }
  let(:authenticated_at) { now - 10.minutes }

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_refresh_token_idle_timeout_in_minutes)
      .and_return(30)
    allow(IdentityConfig.store).to receive(:token_exchange_refresh_token_max_lifetime_in_minutes)
      .and_return(720)
  end

  describe '.issue' do
    subject(:issued) do
      described_class.issue(
        identity:, actor_return_log_id: 42, resource:, dpop_jkt:, authenticated_at:, now:,
      )
    end

    it 'starts a family bound to the key, storing only the digest of the token' do
      record = issued.record

      expect(record.token_digest).to eq(TokenExchangeRefreshToken.digest(issued.token))
      expect(TokenExchangeRefreshToken.where(token_digest: issued.token)).to be_empty
      expect(record).to have_attributes(
        user_id: user.id,
        actor_issuer: service_provider.issuer,
        identity_uuid: identity.uuid,
        scope: 'openid token_exchange',
        ial: 1,
        actor_return_log_id: 42,
        resource:,
        dpop_jkt:,
      )
    end

    it 'caps the family from the authentication, not from now' do
      expect(issued.record.family_expires_at).to eq(authenticated_at + 720.minutes)
      expect(issued.record.expires_at).to eq(now + 30.minutes)
    end

    context 'when the family ends sooner than the idle timeout' do
      let(:authenticated_at) { now - 710.minutes }

      it 'never lets a token outlive its family' do
        expect(issued.record.expires_at).to eq(issued.record.family_expires_at)
      end
    end
  end

  describe '.rotate' do
    let!(:previous) do
      described_class.issue(
        identity:, actor_return_log_id: 42, resource:, dpop_jkt:, authenticated_at:,
        now: now - 5.minutes
      ).record
    end

    it 'marks the token used and issues the next one in the family with a new idle expiry' do
      rotated = described_class.rotate(previous, now:)

      expect(previous.reload.used_at).to eq(now)
      expect(rotated.token).to be_present
      expect(rotated.record).to have_attributes(
        family_id: previous.family_id,
        family_expires_at: previous.family_expires_at,
        authenticated_at: previous.authenticated_at,
        dpop_jkt:,
        actor_return_log_id: 42,
        resource:,
        expires_at: now + 30.minutes,
      )
    end

    it 'issues nothing for a token already used, so only one of two racing requests wins' do
      stale_copy = TokenExchangeRefreshToken.find(previous.id)
      expect(described_class.rotate(previous, now:)).to be_present

      expect(described_class.rotate(stale_copy, now:)).to be_nil
      expect(TokenExchangeRefreshToken.where(family_id: previous.family_id).count).to eq(2)
    end

    it 'issues nothing for a revoked token' do
      previous.revoke_family!(reason: 'revoked_by_client')

      expect(described_class.rotate(previous, now:)).to be_nil
    end
  end
end
