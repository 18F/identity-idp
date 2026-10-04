require 'rails_helper'

RSpec.describe TokenExchangeGrant do
  let(:user) { create(:user) }
  let(:broker) { 'broker.gov' }

  describe '.grant!' do
    it 'materializes one row per target with its own timestamp' do
      described_class.grant!(user:, broker_issuer: broker, targets: %w[a.gov b.gov])

      rows = described_class.where(user:, broker_issuer: broker)
      expect(rows.pluck(:target_issuer)).to match_array(%w[a.gov b.gov])
      expect(rows.pluck(:expires_at)).to all(be_within(1.minute).of(12.months.from_now))
    end

    it 'never stores a wildcard row' do
      described_class.grant!(user:, broker_issuer: broker, targets: %w[a.gov])
      expect(described_class.where(user:).pluck(:target_issuer)).not_to include('*')
    end

    it 'revokes targets dropped from the new set and keeps original timestamps for kept ones' do
      travel_to(3.months.ago) do
        described_class.grant!(user:, broker_issuer: broker, targets: %w[a.gov b.gov])
      end
      original = described_class.find_by(user:, target_issuer: 'a.gov').granted_at

      described_class.grant!(user:, broker_issuer: broker, targets: %w[a.gov c.gov])

      expect(described_class.active.where(user:).pluck(:target_issuer)).to match_array(
        %w[a.gov
           c.gov],
      )
      expect(described_class.find_by(user:, target_issuer: 'b.gov').revoked_at).to be_present
      expect(described_class.find_by(user:, target_issuer: 'a.gov').granted_at).to eq(original)
    end

    it 'revokes everything when given no targets' do
      described_class.grant!(user:, broker_issuer: broker, targets: %w[a.gov])
      described_class.grant!(user:, broker_issuer: broker, targets: [])

      expect(described_class.active.where(user:)).to be_empty
      expect(described_class.where(user:).count).to eq(1)
    end

    it 'stamps newly granted targets with the supplied granted_at' do
      stamp = 2.months.ago.change(usec: 0)
      described_class.grant!(user:, broker_issuer: broker, targets: %w[a.gov], granted_at: stamp)

      grant = described_class.find_by(user:, target_issuer: 'a.gov')
      expect(grant.granted_at).to eq(stamp)
      expect(grant.expires_at).to eq(stamp + described_class::GRANT_DURATION)
    end

    it 'does not touch grants for a different broker' do
      described_class.grant!(user:, broker_issuer: 'other-broker.gov', targets: %w[z.gov])
      described_class.grant!(user:, broker_issuer: broker, targets: %w[a.gov])

      expect(described_class.active.where(user:, broker_issuer: 'other-broker.gov')).to exist
    end
  end

  describe '.grant_one!' do
    it 'adds a target without disturbing others, honoring the supplied timestamp' do
      described_class.grant!(user:, broker_issuer: broker, targets: %w[a.gov])
      stamp = 1.month.ago.change(usec: 0)

      described_class.grant_one!(
        user:, broker_issuer: broker, target_issuer: 'b.gov',
        granted_at: stamp
      )

      expect(described_class.active.where(user:).pluck(:target_issuer)).to match_array(
        %w[a.gov
           b.gov],
      )
      expect(described_class.find_by(user:, target_issuer: 'b.gov').granted_at).to eq(stamp)
    end

    it 'is idempotent for an already-active grant' do
      described_class.grant_one!(user:, broker_issuer: broker, target_issuer: 'a.gov')
      first = described_class.find_by(user:, target_issuer: 'a.gov').granted_at

      described_class.grant_one!(
        user:, broker_issuer: broker, target_issuer: 'a.gov',
        granted_at: 1.day.ago
      )

      expect(described_class.find_by(user:, target_issuer: 'a.gov').granted_at).to eq(first)
    end
  end

  describe '.authorizes?' do
    it 'authorizes only an exact per-application row' do
      described_class.grant!(user:, broker_issuer: broker, targets: %w[a.gov])

      expect(
        described_class.authorizes?(
          user:, broker_issuer: broker,
          target_issuer: 'a.gov'
        ),
      ).to eq(true)
      expect(
        described_class.authorizes?(
          user:, broker_issuer: broker,
          target_issuer: 'b.gov'
        ),
      ).to eq(false)
      expect(
        described_class.authorizes?(
          user:, broker_issuer: broker,
          target_issuer: '*'
        ),
      ).to eq(false)
    end

    it 'is false once the grant has expired or been revoked' do
      described_class.grant!(user:, broker_issuer: broker, targets: %w[a.gov])

      travel_to(13.months.from_now) do
        expect(
          described_class.authorizes?(
            user:, broker_issuer: broker,
            target_issuer: 'a.gov'
          ),
        ).to eq(false)
      end

      described_class.revoke!(user:, broker_issuer: broker, target_issuer: 'a.gov')
      expect(
        described_class.authorizes?(
          user:, broker_issuer: broker,
          target_issuer: 'a.gov'
        ),
      ).to eq(false)
    end

    it 'is scoped to the broker' do
      described_class.grant!(user:, broker_issuer: broker, targets: %w[a.gov])
      expect(
        described_class.authorizes?(
          user:, broker_issuer: 'other.gov',
          target_issuer: 'a.gov'
        ),
      ).to eq(false)
    end
  end
end
