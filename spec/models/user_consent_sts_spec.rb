require 'rails_helper'

RSpec.describe UserConsentSts do
  let(:user) { create(:user) }

  describe 'associations' do
    it 'belongs to a user' do
      consent = described_class.new(user:, target_app: 'issuer')

      expect(consent.user).to eq(user)
    end
  end

  describe 'validations' do
    it 'requires a user' do
      consent = described_class.new(user: nil, target_app: 'issuer')

      expect(consent).not_to be_valid
      expect(consent.errors[:user]).to be_present
    end

    it 'requires target_app' do
      consent = described_class.new(user:, target_app: nil)

      expect(consent).not_to be_valid
      expect(consent.errors[:target_app]).to be_present
    end

    it 'is valid with both a user and target_app' do
      consent = described_class.new(user:, target_app: 'issuer')

      expect(consent).to be_valid
    end
  end

  describe 'uniqueness' do
    it 'enforces uniqueness of user + target_app at the database level' do
      target_app = 'issuer'
      described_class.create!(user:, target_app:)

      expect do
        described_class.create!(user:, target_app:)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows the same user for a different target_app' do
      described_class.create!(user:, target_app: 'app-a')

      expect do
        described_class.create!(user:, target_app: 'app-b')
      end.not_to raise_error
    end
  end

  describe '#unexpired?' do
    before do
      allow(IdentityConfig.store).to receive(:sts_consent_expiration_in_days).and_return(365)
    end

    it 'is true when consent is within the expiration window' do
      consent = described_class.create!(user:, target_app: 'issuer')

      expect(consent.unexpired?).to eq(true)
    end

    it 'is false when consent is older than the expiration window' do
      consent = described_class.create!(user:, target_app: 'issuer')
      consent.update!(created_at: 366.days.ago)

      expect(consent.unexpired?).to eq(false)
    end
  end

  describe '.consent_valid?' do
    before do
      allow(IdentityConfig.store).to receive(:sts_consent_expiration_in_days).and_return(365)
    end

    it 'is false when no consent record exists' do
      expect(described_class.consent_valid?(user:, target_app: 'issuer')).to eq(false)
    end

    it 'is true when an unexpired consent exists' do
      described_class.create!(user:, target_app: 'issuer')

      expect(described_class.consent_valid?(user:, target_app: 'issuer')).to eq(true)
    end

    it 'is false when the consent is expired' do
      consent = described_class.create!(user:, target_app: 'issuer')
      consent.update!(created_at: 366.days.ago)

      expect(described_class.consent_valid?(user:, target_app: 'issuer')).to eq(false)
    end
  end
end
