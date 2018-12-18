require 'rails_helper'

describe TwoFactorAuthentication::BackupCodePolicy do
  let(:user) { User.new }
  let(:policy) { described_class.new(user) }

  describe '#configured?' do
    it 'returns false if there are no codes' do
      expect(policy.configured?).to eq false
    end

    it 'returns false if all the backup codes are used' do
      user.save
      user.backup_code_configurations.create!(code: 'foo', used: true)

      expect(policy.configured?).to eq false
    end

    it 'returns true if there are usable codes' do
      user.save
      user.backup_code_configurations.create!(code: 'foo')

      expect(policy.configured?).to eq true
    end
  end

  describe '#enabled?' do
    it 'returns false if there are no codes' do
      expect(policy.enabled?).to eq false
    end

    it 'returns false if all the backup codes are used' do
      user.save
      user.backup_code_configurations.create!(code: 'foo', used: true)

      expect(policy.enabled?).to eq false
    end

    it 'returns true if there are usable codes' do
      user.save
      user.backup_code_configurations.create!(code: 'foo')

      expect(policy.enabled?).to eq true
    end
  end

  describe '#visible?' do
    it 'returns true if backup codes are enabled' do
      allow(FeatureManagement).to receive(:backup_codes_enabled?).and_return(true)
      expect(policy.visible?).to eq true
    end

    it 'returns false if backup codes are disabled' do
      allow(FeatureManagement).to receive(:backup_codes_enabled?).and_return(false)
      expect(policy.visible?).to eq false
    end
  end

  describe '#available?' do
    it 'returns true if backup codes are enabled' do
      allow(FeatureManagement).to receive(:backup_codes_enabled?).and_return(true)
      expect(policy.visible?).to eq true
    end

    it 'returns false if backup codes are disabled' do
      allow(FeatureManagement).to receive(:backup_codes_enabled?).and_return(false)
      expect(policy.visible?).to eq false
    end
  end
end
