require 'rails_helper'

RSpec.describe TokenExchange::AccessToken do
  describe '.redis_key_prefix' do
    it 'uses a distinct Redis key namespace' do
      expect(described_class.redis_key_prefix).to eq('token-exchange-access-token')
    end
  end

  describe '.digest' do
    it 'returns the SHA-256 hex digest of the opaque token' do
      expect(described_class.digest('opaque-token')).to eq(
        Digest::SHA256.hexdigest('opaque-token'),
      )
    end
  end

  describe '.load' do
    it 'loads access token metadata by digest, not raw token' do
      token = 'opaque-access-token'
      access_token = described_class.new(
        id: described_class.digest(token),
        user_id: 1,
        identity_uuid: 'identity-uuid',
        broker_issuer: 'broker-issuer',
        target_issuer: 'target-issuer',
        resource: 'https://api.example.gov/passport',
        scope: 'openid token_exchange:passport',
        issued_at: Time.zone.now.to_i,
      )

      EncryptedRedisStructStorage.store(access_token, expires_in: 600)

      expect(described_class.load(token)).to have_attributes(
        id: described_class.digest(token),
        user_id: 1,
        identity_uuid: 'identity-uuid',
        broker_issuer: 'broker-issuer',
        target_issuer: 'target-issuer',
        resource: 'https://api.example.gov/passport',
        scope: 'openid token_exchange:passport',
      )
    end

    it 'returns nil when the token is not in Redis' do
      expect(described_class.load('missing-token')).to be_nil
    end
  end

  describe '#expired?' do
    subject(:access_token) { described_class.new(expires_at:) }

    let(:now) { Time.zone.parse('2026-10-14 12:00:00 UTC') }

    context 'when the expiration is in the future' do
      let(:expires_at) { now.to_i + 1 }

      it 'is not expired' do
        expect(access_token.expired?(now:)).to eq(false)
        expect(access_token.active?(now:)).to eq(true)
      end
    end

    context 'when the expiration is in the past' do
      let(:expires_at) { now.to_i - 1 }

      it 'is expired' do
        expect(access_token.expired?(now:)).to eq(true)
        expect(access_token.active?(now:)).to eq(false)
      end
    end

    context 'when the expiration is exactly now' do
      let(:expires_at) { now.to_i }

      it 'is expired' do
        expect(access_token.expired?(now:)).to eq(true)
      end
    end

    context 'when the expiration is missing' do
      let(:expires_at) { nil }

      it 'fails closed and is expired' do
        expect(access_token.expired?(now:)).to eq(true)
        expect(access_token.active?(now:)).to eq(false)
      end
    end

    it 'defaults to the current time' do
      expect(described_class.new(expires_at: 1.minute.from_now.to_i).expired?).to eq(false)
      expect(described_class.new(expires_at: 1.minute.ago.to_i).expired?).to eq(true)
    end
  end
end
