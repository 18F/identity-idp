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
