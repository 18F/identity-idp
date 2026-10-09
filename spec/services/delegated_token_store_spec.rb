require 'rails_helper'

RSpec.describe DelegatedTokenStore do
  let(:token) { TokenExchangeToken.generate_token }
  let(:grant_id) { SecureRandom.random_number(1_000_000) }
  let(:family_id) { SecureRandom.uuid }
  let(:attributes) do
    {
      aud: 'https://records-api.housing.example.gov',
      scope: 'token_exchange:housing_records',
      grant_id:,
      delegation_id: 'dlg_example',
      refresh_family_id: family_id,
      ial: 2,
      aal: 2,
      dpop_jkt: nil,
      token_type: 'Bearer',
      issuance_id: 42,
    }
  end

  after do
    described_class.revoke_grant(grant_id)
    described_class.revoke_family(family_id)
  end

  def redis_ttl(key)
    REDIS_POOL.with { |client| client.ttl(key) }
  end

  describe '.write and .read' do
    it 'stores the entry under the digest with the token lifetime as TTL' do
      described_class.write(token, attributes, ttl: 900)

      expect(described_class.read(token)).to eq(attributes)
      key = DelegatedTokenStore::TOKEN_KEY_PREFIX + Digest::SHA256.hexdigest(token)
      expect(redis_ttl(key)).to be_between(890, 900)
    end

    it 'never stores the token string itself' do
      described_class.write(token, attributes, ttl: 900)
      keys = REDIS_POOL.with { |client| client.keys("#{DelegatedTokenStore::TOKEN_KEY_PREFIX}*") }
      expect(keys.join).not_to include(token)
    end

    it 'lists the digest in the grant and family index sets with a TTL that only grows' do
      described_class.write(token, attributes, ttl: 900)
      described_class.write(TokenExchangeToken.generate_token, attributes, ttl: 60)

      grant_key = DelegatedTokenStore::GRANT_INDEX_PREFIX + grant_id.to_s
      family_key = DelegatedTokenStore::FAMILY_INDEX_PREFIX + family_id
      expect(REDIS_POOL.with { |c| c.scard(grant_key) }).to eq(2)
      expect(REDIS_POOL.with { |c| c.scard(family_key) }).to eq(2)
      expect(redis_ttl(grant_key)).to be_between(890, 900)
      expect(redis_ttl(family_key)).to be_between(890, 900)
    end

    it 'reads nil for an unknown or blank token' do
      expect(described_class.read(TokenExchangeToken.generate_token)).to be_nil
      expect(described_class.read(nil)).to be_nil
      expect(described_class.read('')).to be_nil
    end
  end

  describe '.move_grant' do
    let(:new_grant_id) { grant_id + 1 }

    after { described_class.revoke_grant(new_grant_id) }

    it 'rewrites each live entry for the new grant, keeps its lifetime, and moves the index' do
      described_class.write(token, attributes, ttl: 600)

      expect(described_class.move_grant(grant_id, new_grant_id)).to eq(1)

      expect(described_class.read(token)[:grant_id]).to eq(new_grant_id)
      expect(redis_ttl(described_class::TOKEN_KEY_PREFIX + described_class.digest(token)))
        .to be_between(590, 600)
      expect(REDIS_POOL.with { |c| c.exists(described_class::GRANT_INDEX_PREFIX + grant_id.to_s) })
        .to eq(0)
      expect(described_class.revoke_grant(new_grant_id)).to eq(1)
      expect(described_class.read(token)).to be_nil
    end

    it 'moves nothing for an approval without live tokens' do
      expect(described_class.move_grant(grant_id, new_grant_id)).to eq(0)
    end
  end

  describe '.revoke_grant' do
    it 'removes every token listed for the grant and the set itself' do
      other = TokenExchangeToken.generate_token
      described_class.write(token, attributes, ttl: 900)
      described_class.write(other, attributes, ttl: 900)

      expect(described_class.revoke_grant(grant_id)).to eq(2)
      expect(described_class.read(token)).to be_nil
      expect(described_class.read(other)).to be_nil
      grant_key = DelegatedTokenStore::GRANT_INDEX_PREFIX + grant_id.to_s
      expect(REDIS_POOL.with { |c| c.exists?(grant_key) }).to eq(false)
    end

    it 'leaves tokens of other grants alone' do
      other_grant = grant_id + 1
      other = TokenExchangeToken.generate_token
      described_class.write(token, attributes, ttl: 900)
      described_class.write(other, attributes.merge(grant_id: other_grant), ttl: 900)

      described_class.revoke_grant(grant_id)
      expect(described_class.read(other)).to be_present
      described_class.revoke_grant(other_grant)
    end

    it 'returns zero for a grant with no live tokens' do
      expect(described_class.revoke_grant(grant_id)).to eq(0)
    end
  end

  describe '.revoke_family' do
    it 'removes every token of the family' do
      described_class.write(token, attributes, ttl: 900)
      expect(described_class.revoke_family(family_id)).to eq(1)
      expect(described_class.read(token)).to be_nil
    end
  end
end
