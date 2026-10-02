require 'rails_helper'

RSpec.describe TokenExchangeGrant do
  let(:user) { create(:user) }
  let(:broker) { 'broker.gov' }

  describe '.record!' do
    it 'snapshots every reachable target plus an all-targets row for :all' do
      described_class.record!(user:, broker_issuer: broker, choice: :all, targets: %w[a.gov b.gov])

      rows = described_class.where(user:, broker_issuer: broker)
      expect(rows.pluck(:target_issuer)).to match_array(
        [described_class::ALL_TARGETS, 'a.gov',
         'b.gov'],
      )
      expect(rows.find_by(target_issuer: described_class::ALL_TARGETS).includes_future).to eq(false)
      expect(rows.pluck(:expires_at)).to all(be_within(1.minute).of(12.months.from_now))
    end

    it 'marks the all-targets row includes_future for :all_and_future' do
      described_class.record!(
        user:, broker_issuer: broker, choice: :all_and_future,
        targets: ['a.gov']
      )

      expect(
        described_class.find_by(
          user:,
          target_issuer: described_class::ALL_TARGETS,
        ).includes_future,
      )
        .to eq(true)
    end

    it 'records only the chosen targets for :specific' do
      described_class.record!(user:, broker_issuer: broker, choice: :specific, targets: ['a.gov'])

      expect(described_class.where(user:).pluck(:target_issuer)).to eq(['a.gov'])
    end

    it 'revokes rather than deletes superseded grants, preserving the audit trail' do
      described_class.record!(user:, broker_issuer: broker, choice: :specific, targets: ['a.gov'])
      described_class.record!(user:, broker_issuer: broker, choice: :specific, targets: ['b.gov'])

      expect(described_class.where(user:).count).to eq(2)
      expect(described_class.active.where(user:).pluck(:target_issuer)).to eq(['b.gov'])
    end

    it 'refuses an all-current grant that would cover nothing' do
      expect do
        described_class.record!(user:, broker_issuer: broker, choice: :all, targets: [])
      end.to raise_error(described_class::InvalidGrant)
    end

    it 'allows an all-and-future grant with no current targets' do
      described_class.record!(user:, broker_issuer: broker, choice: :all_and_future, targets: [])
      expect(described_class.authorizes?(user:, broker_issuer: broker, target_issuer: 'later.gov'))
        .to eq(true)
    end

    it 'refuses the sentinel as a target' do
      expect do
        described_class.record!(user:, broker_issuer: broker, choice: :specific, targets: ['*'])
      end.to raise_error(described_class::InvalidGrant)
    end

    it 'does not touch grants for a different broker' do
      described_class.record!(
        user:, broker_issuer: 'other-broker.gov', choice: :all,
        targets: ['z.gov']
      )
      described_class.record!(user:, broker_issuer: broker, choice: :specific, targets: ['a.gov'])

      expect(described_class.where(user:, broker_issuer: 'other-broker.gov')).to exist
    end
  end

  describe '.authorizes?' do
    it 'is true for an explicitly granted target' do
      described_class.record!(user:, broker_issuer: broker, choice: :specific, targets: ['a.gov'])

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
    end

    it 'does not extend an all-targets (non-future) grant to a later target' do
      described_class.record!(user:, broker_issuer: broker, choice: :all, targets: ['a.gov'])

      expect(
        described_class.authorizes?(
          user:, broker_issuer: broker,
          target_issuer: 'a.gov'
        ),
      ).to eq(true)
      expect(
        described_class.authorizes?(
          user:, broker_issuer: broker,
          target_issuer: 'new.gov'
        ),
      ).to eq(false)
    end

    it 'extends an all-and-future grant to a later target' do
      described_class.record!(
        user:, broker_issuer: broker, choice: :all_and_future,
        targets: ['a.gov']
      )

      expect(
        described_class.authorizes?(
          user:, broker_issuer: broker,
          target_issuer: 'new.gov'
        ),
      ).to eq(true)
    end

    it 'is false once the grant has expired or been revoked' do
      described_class.record!(
        user:, broker_issuer: broker, choice: :all_and_future,
        targets: ['a.gov']
      )

      travel_to(13.months.from_now) do
        expect(
          described_class.authorizes?(
            user:, broker_issuer: broker,
            target_issuer: 'a.gov'
          ),
        ).to eq(false)
      end

      described_class.revoke_all!(user:, broker_issuer: broker)
      expect(
        described_class.authorizes?(
          user:, broker_issuer: broker,
          target_issuer: 'a.gov'
        ),
      ).to eq(false)
    end

    it 'never authorizes the sentinel itself as a target' do
      described_class.record!(user:, broker_issuer: broker, choice: :all, targets: ['a.gov'])
      expect(
        described_class.authorizes?(
          user:, broker_issuer: broker,
          target_issuer: '*'
        ),
      ).to eq(false)
    end

    it 'is scoped to the broker' do
      described_class.record!(
        user:, broker_issuer: broker, choice: :all_and_future,
        targets: ['a.gov']
      )

      expect(
        described_class.authorizes?(
          user:, broker_issuer: 'other.gov',
          target_issuer: 'a.gov'
        ),
      ).to eq(false)
    end
  end
end
