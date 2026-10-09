require 'rails_helper'

RSpec.describe TokenExchangeRefreshToken do
  describe 'validations' do
    it 'is valid from the factory' do
      expect(build(:token_exchange_refresh_token)).to be_valid
    end

    it 'requires a unique digest' do
      plaintext = described_class.generate_token
      create(:token_exchange_refresh_token, plaintext:)
      expect(build(:token_exchange_refresh_token, plaintext:)).not_to be_valid
    end
  end

  describe '.generate_token and .digest' do
    it 'returns a 43-character base64url string, looked up only by its SHA-256 digest' do
      token = described_class.generate_token
      expect(token).to match(/\A[A-Za-z0-9_-]{43}\z/)
      expect(described_class.generate_token).not_to eq(token)
      expect(described_class.digest(token)).to eq(Digest::SHA256.hexdigest(token))
    end
  end

  describe '.lookup' do
    it 'finds the row for a token string whatever its state, and nothing for garbage' do
      plaintext = described_class.generate_token
      row = create(:token_exchange_refresh_token, :rotated, plaintext:)
      expect(described_class.lookup(plaintext)).to eq(row)
      expect(described_class.lookup(described_class.generate_token)).to be_nil
      expect(described_class.lookup(nil)).to be_nil
      expect(described_class.lookup("a\x00b")).to be_nil
    end

    it 'never stores the token string' do
      plaintext = described_class.generate_token
      row = create(:token_exchange_refresh_token, plaintext:)
      expect(row.attributes.values.map(&:to_s)).not_to include(plaintext)
    end
  end

  describe '.live' do
    it 'excludes rotated, revoked and ended rows' do
      live = create(:token_exchange_refresh_token)
      create(:token_exchange_refresh_token, :rotated)
      create(:token_exchange_refresh_token, :revoked)
      create(:token_exchange_refresh_token, expires_at: 1.second.ago)

      expect(described_class.live).to eq([live])
    end
  end

  describe '.family_end' do
    let(:now) { Time.zone.now.change(usec: 0) }
    let(:grant) { build(:token_exchange_grant, remember_until: now + 1.year) }
    let(:resource_server) { build(:token_exchange_resource_server) }
    let(:service_provider) { build(:service_provider) }

    def family_end
      described_class.family_end(from: now, grant:, resource_server:, service_provider:)
    end

    it 'is twelve hours from the exchange by default' do
      expect(family_end).to eq(now + 12.hours)
    end

    it 'follows the configured lifetime' do
      allow(IdentityConfig.store).to receive(:token_exchange_refresh_token_ttl_seconds)
        .and_return(3600)
      expect(family_end).to eq(now + 1.hour)
    end

    it 'is shortened by the API, by the service provider, and by the remembered period' do
      resource_server.max_family_seconds = 4.hours.to_i
      expect(family_end).to eq(now + 4.hours)

      service_provider.delegation_max_family_seconds = 2.hours.to_i
      expect(family_end).to eq(now + 2.hours)

      grant.remember_until = now + 30.minutes
      expect(family_end).to eq(now + 30.minutes)
    end

    it 'is never lengthened by a limit above the default' do
      resource_server.max_family_seconds = 2.days.to_i
      service_provider.delegation_max_family_seconds = 2.days.to_i
      expect(family_end).to eq(now + 12.hours)
    end

    it 'gives a single-authorization approval the full lifetime' do
      grant.remember_until = nil
      expect(family_end).to eq(now + 12.hours)
    end
  end

  describe '.revoke_family!' do
    it 'removes the live access tokens and marks every row of the family, keeping old reasons' do
      plaintext = TokenExchangeToken.generate_token
      issuance = create(:token_exchange_token, plaintext:)
      family_id = issuance.refresh_family_id
      spent = create(:token_exchange_refresh_token, :rotated, token_exchange_token: issuance)
      current = create(:token_exchange_refresh_token, token_exchange_token: issuance)
      earlier = create(
        :token_exchange_refresh_token, :revoked, token_exchange_token: issuance,
                                                 revocation_reason: 'client_revoked'
      )
      other_family = create(:token_exchange_refresh_token)

      freeze_time do
        described_class.revoke_family!(family_id, reason: 'refresh_token_reuse')

        expect(DelegatedTokenStore.read(plaintext)).to be_nil
        expect(issuance.reload.revoked_at).to eq(Time.zone.now)
        expect(issuance.revocation_reason).to eq('refresh_token_reuse')
        [spent, current].each do |row|
          expect(row.reload.revoked_at).to eq(Time.zone.now)
          expect(row.revocation_reason).to eq('refresh_token_reuse')
        end
        expect(earlier.reload.revocation_reason).to eq('client_revoked')
        expect(other_family.reload.revoked_at).to be_nil
      end
    end
  end

  describe 'state' do
    it 'reports rotation, revocation, key binding and the family end' do
      row = build(:token_exchange_refresh_token, expires_at: 90.seconds.from_now)
      expect(row).not_to be_rotated
      expect(row).not_to be_revoked
      expect(row).not_to be_key_bound
      expect(row.family_ended?).to eq(false)
      expect(row.seconds_until_family_end).to be_between(89, 90)

      row.dpop_jkt = 'thumbprint'
      expect(row).to be_key_bound

      row.expires_at = 1.second.ago
      expect(row.family_ended?).to eq(true)
      expect(row.seconds_until_family_end).to eq(0)
    end
  end
end
