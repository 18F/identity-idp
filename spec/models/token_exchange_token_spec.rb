require 'rails_helper'

RSpec.describe TokenExchangeToken do
  describe 'validations' do
    it 'is valid from the factory' do
      expect(build(:token_exchange_token)).to be_valid
    end

    it 'accepts only the three RFC token types' do
      expect(build(:token_exchange_token, token_type: 'DPoP')).to be_valid
      expect(build(:token_exchange_token, token_type: 'N_A')).to be_valid
      expect(build(:token_exchange_token, token_type: 'bearer')).not_to be_valid
    end

    it 'accepts only the registered token formats' do
      expect(build(:token_exchange_token, token_format: 'saml2')).to be_valid
      expect(build(:token_exchange_token, token_format: 'jwt')).not_to be_valid
    end
  end

  describe '.generate_token' do
    it 'returns a 43-character base64url string with no padding' do
      token = described_class.generate_token
      expect(token).to match(/\A[A-Za-z0-9_-]{43}\z/)
      expect(described_class.generate_token).not_to eq(token)
    end
  end

  describe '#live_attributes' do
    it 'is the Redis entry introspection reads, with epoch times and the record ids' do
      token = create(:token_exchange_token, :key_bound, sp_rails_session_id: 'session-1')

      expect(token.live_attributes).to eq(
        aud: token.resource_server.identifier,
        scope: token.scope,
        grant_id: token.grant_id,
        delegation_id: token.delegation_id,
        user_id: token.user_id,
        service_provider_id: token.service_provider_id,
        resource_server_id: token.resource_server_id,
        ial: 2,
        aal: 2,
        refresh_family_id: token.refresh_family_id,
        dpop_jkt: token.dpop_jkt,
        token_type: 'DPoP',
        token_format: 'oauth',
        sp_rails_session_id: 'session-1',
        issued_at: token.issued_at.to_i,
        expires_at: token.expires_at.to_i,
        issuance_id: token.id,
      )
    end

    it 'takes the times of a later token of the family in place of the record\'s' do
      token = create(:token_exchange_token)
      now = 1.hour.from_now.change(usec: 0)

      entry = token.live_attributes(issued_at: now, expires_at: now + 300)
      expect(entry).to include(
        issued_at: now.to_i, expires_at: (now + 300).to_i, issuance_id: token.id,
      )
    end
  end

  describe '#record_refresh!' do
    it 'counts the refresh and records its instant, once per refresh' do
      token = create(:token_exchange_token)
      expect(token.refresh_count).to eq(0)
      expect(token.last_refreshed_at).to be_nil

      first = 1.minute.from_now.change(usec: 0)
      token.record_refresh!(now: first)
      expect(token.refresh_count).to eq(1)
      expect(token.last_refreshed_at).to eq(first)

      second = 2.minutes.from_now.change(usec: 0)
      token.record_refresh!(now: second)
      expect(token.reload.refresh_count).to eq(2)
      expect(token.last_refreshed_at).to eq(second)
      expect(token.updated_at).to eq(second)
    end
  end

  describe '.live' do
    it 'excludes revoked and expired rows' do
      live = create(:token_exchange_token)
      create(:token_exchange_token, :revoked)
      create(:token_exchange_token, issued_at: 20.minutes.ago, expires_at: 5.minutes.ago)

      expect(described_class.live).to eq([live])
    end
  end

  describe '#lifetime_seconds' do
    it 'is the distance between issuance and expiry' do
      now = Time.zone.now
      token = build(:token_exchange_token, issued_at: now, expires_at: now + 300)
      expect(token.lifetime_seconds).to eq(300)
    end
  end

  describe '#key_bound?' do
    it 'is true only with a thumbprint' do
      expect(build(:token_exchange_token)).not_to be_key_bound
      expect(build(:token_exchange_token, :key_bound)).to be_key_bound
    end
  end

  describe '#revoke!' do
    it 'records the time and the reason' do
      token = create(:token_exchange_token)
      freeze_time do
        token.revoke!(reason: 'user_revoked')
        expect(token.revoked_at).to eq(Time.zone.now)
        expect(token.revocation_reason).to eq('user_revoked')
        expect(token).to be_revoked
      end
    end
  end

  describe 'the factory plaintext' do
    it 'stores the live token in Redis so endpoints can be handed the token' do
      plaintext = described_class.generate_token
      token = create(:token_exchange_token, plaintext:)

      entry = DelegatedTokenStore.read(plaintext)
      expect(entry[:aud]).to eq(token.resource_server.identifier)
      expect(entry[:issuance_id]).to eq(token.id)
      DelegatedTokenStore.revoke_grant(token.grant_id)
    end
  end
end
