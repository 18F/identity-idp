require 'rails_helper'

RSpec.describe UserConsentSts do
  let(:user) { create(:user) }

  describe 'associations' do
    it 'belongs to a user' do
      consent = described_class.new(user:, target_app: 'issuer', actor_app: 'broker')

      expect(consent.user).to eq(user)
    end
  end

  describe 'validations' do
    it 'requires a user' do
      consent = described_class.new(user: nil, target_app: 'issuer', actor_app: 'broker')

      expect(consent).not_to be_valid
      expect(consent.errors[:user]).to be_present
    end

    it 'requires target_app' do
      consent = described_class.new(user:, target_app: nil, actor_app: 'broker')

      expect(consent).not_to be_valid
      expect(consent.errors[:target_app]).to be_present
    end

    it 'requires actor_app' do
      consent = described_class.new(user:, target_app: 'issuer', actor_app: nil)

      expect(consent).not_to be_valid
      expect(consent.errors[:actor_app]).to be_present
    end

    it 'is valid with a user, target_app, and actor_app' do
      consent = described_class.new(user:, target_app: 'issuer', actor_app: 'broker')

      expect(consent).to be_valid
    end
  end

  describe 'uniqueness' do
    it 'enforces uniqueness of active user + target_app + actor_app at the database level' do
      target_app = 'issuer'
      actor_app = 'broker'
      described_class.create!(user:, target_app:, actor_app:)

      expect do
        described_class.create!(user:, target_app:, actor_app:)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows the same user for a different target_app' do
      described_class.create!(user:, target_app: 'app-a', actor_app: 'broker')

      expect do
        described_class.create!(user:, target_app: 'app-b', actor_app: 'broker')
      end.not_to raise_error
    end

    it 'allows the same user and target_app for a different actor_app' do
      described_class.create!(user:, target_app: 'issuer', actor_app: 'broker-a')

      expect do
        described_class.create!(user:, target_app: 'issuer', actor_app: 'broker-b')
      end.not_to raise_error
    end

    it 'allows a new active consent once the prior one for the same triple is revoked' do
      target_app = 'issuer'
      actor_app = 'broker'
      consent = described_class.create!(user:, target_app:, actor_app:)
      consent.update!(is_revoked: true)

      expect do
        described_class.create!(user:, target_app:, actor_app:)
      end.not_to raise_error
    end
  end

  describe '#unexpired?' do
    before do
      allow(IdentityConfig.store).to receive(:sts_consent_expiration_in_days).and_return(365)
    end

    it 'is true when consent is within the expiration window' do
      consent = described_class.create!(user:, target_app: 'issuer', actor_app: 'broker')

      expect(consent.unexpired?).to eq(true)
    end

    it 'is false when consent is older than the expiration window' do
      consent = described_class.create!(user:, target_app: 'issuer', actor_app: 'broker')
      consent.update!(created_at: 366.days.ago)

      expect(consent.unexpired?).to eq(false)
    end
  end

  describe '.unexpired' do
    before do
      allow(IdentityConfig.store).to receive(:sts_consent_expiration_in_days).and_return(365)
    end

    it 'includes consents within the expiration window' do
      consent = described_class.create!(user:, target_app: 'issuer', actor_app: 'broker')

      expect(described_class.unexpired).to eq([consent])
    end

    it 'excludes consents older than the expiration window' do
      consent = described_class.create!(user:, target_app: 'issuer', actor_app: 'broker')
      consent.update!(created_at: 366.days.ago)

      expect(described_class.unexpired).to be_empty
    end
  end

  describe '.active' do
    it 'includes non-revoked consents' do
      consent = described_class.create!(user:, target_app: 'issuer', actor_app: 'broker')

      expect(described_class.active).to eq([consent])
    end

    it 'excludes revoked consents' do
      consent = described_class.create!(user:, target_app: 'issuer', actor_app: 'broker')
      consent.update!(is_revoked: true)

      expect(described_class.active).to be_empty
    end
  end

  describe '.consent_valid?' do
    before do
      allow(IdentityConfig.store).to receive(:sts_consent_expiration_in_days).and_return(365)
    end

    it 'is false when no consent record exists' do
      expect(
        described_class.consent_valid?(user:, target_app: 'issuer', actor_app: 'broker'),
      ).to eq(false)
    end

    it 'is true when an unexpired, non-revoked consent exists' do
      described_class.create!(user:, target_app: 'issuer', actor_app: 'broker')

      expect(
        described_class.consent_valid?(user:, target_app: 'issuer', actor_app: 'broker'),
      ).to eq(true)
    end

    it 'is false when the consent is expired' do
      consent = described_class.create!(user:, target_app: 'issuer', actor_app: 'broker')
      consent.update!(created_at: 366.days.ago)

      expect(
        described_class.consent_valid?(user:, target_app: 'issuer', actor_app: 'broker'),
      ).to eq(false)
    end

    it 'is false when the consent is revoked' do
      consent = described_class.create!(user:, target_app: 'issuer', actor_app: 'broker')
      consent.update!(is_revoked: true)

      expect(
        described_class.consent_valid?(user:, target_app: 'issuer', actor_app: 'broker'),
      ).to eq(false)
    end
  end
end
