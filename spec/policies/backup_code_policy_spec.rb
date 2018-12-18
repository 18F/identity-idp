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
    it 'is set to false' do
      expect(policy.enabled?).to eq false
    end
  end

  describe '#visible?' do
    it 'is always set to true' do
      expect(policy.visible?).to eq true
    end
  end

  describe '#available?' do
    it 'is set to true' do
      expect(policy.available?).to eq true
    end
  end
end
