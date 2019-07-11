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
      user.backup_code_configurations.create!(code: 'foo', used_at: Time.zone.now)

      expect(policy.configured?).to eq false
    end

    it 'returns true if there are usable codes' do
      user.save
      user.backup_code_configurations.create!(code: 'foo')

      expect(policy.configured?).to eq true
    end
  end
end
