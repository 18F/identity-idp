require 'rails_helper'

describe TwoFactorAuthentication::BackupCodePolicy do
  let(:user) { User.new }
  let(:policy) { described_class.new(user) }

  describe '#configured?' do
    it 'is set to false' do
      expect(policy.configured?).to eq false
    end
  end

  describe '#enabled?' do
    it 'is set to false' do
      expect(policy.enabled?).to eq false
    end
  end

  describe '#visible?' do
    it 'is set to true' do
      expect(policy.visible?).to eq true
    end
  end

  describe '#available?' do
    it 'is set to true' do
      expect(policy.available?).to eq true
    end
  end
end
