require 'rails_helper'

RSpec.describe TokenExchangeRefreshToken do
  let(:now) { Time.zone.now }

  describe '.for_token' do
    it 'finds a token by the digest of its value' do
      record = create(:token_exchange_refresh_token, token: 'the-token')

      expect(described_class.for_token('the-token')).to eq(record)
      expect(described_class.for_token('another-token')).to be_nil
      expect(described_class.for_token(nil)).to be_nil
    end
  end

  describe '.revoke_families!' do
    let(:family_id) { SecureRandom.uuid }
    let!(:used) { create(:token_exchange_refresh_token, family_id:, used_at: now) }
    let!(:current) { create(:token_exchange_refresh_token, family_id:) }
    let!(:other_family) { create(:token_exchange_refresh_token) }

    it 'revokes every token in the families and none outside them' do
      expect(described_class.revoke_families!([family_id], reason: 'revoked_by_client', now:))
        .to eq(2)

      expect(used.reload.revoked_at.to_i).to eq(now.to_i)
      expect(current.reload.revocation_reason).to eq('revoked_by_client')
      expect(other_family.reload.revoked_at).to be_nil
    end

    it 'leaves the reason of a token revoked earlier unchanged' do
      described_class.revoke_families!([family_id], reason: 'reuse_detected')

      expect(described_class.revoke_families!([family_id], reason: 'security_event')).to eq(0)
      expect(current.reload.revocation_reason).to eq('reuse_detected')
    end

    it 'refuses an unknown reason' do
      expect { described_class.revoke_families!([family_id], reason: 'other') }
        .to raise_error(ArgumentError)
    end
  end

  describe '#expired?' do
    it 'is expired once either the idle expiry or the family lifetime has passed' do
      expect(build(:token_exchange_refresh_token, expires_at: now + 1.minute)).not_to be_expired
      expect(build(:token_exchange_refresh_token, expires_at: now - 1.second)).to be_expired
      expect(
        build(:token_exchange_refresh_token, family_expires_at: now - 1.second),
      ).to be_expired
    end
  end
end
