require 'rails_helper'

RSpec.describe BackupCodeConfiguration, type: :model do
  describe 'Methods' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to respond_to(:mfa_enabled?) }
    it { is_expected.to respond_to(:selection_presenters) }
    it { is_expected.to respond_to(:friendly_name) }
  end

  describe 'self.unused' do
    it 'is set to false' do
      expect(BackupCodeConfiguration.unused.count).to eq 0
    end
  end

  describe 'mfa_enabled?' do
    it 'is set to false' do
      backup_code_config = BackupCodeConfiguration.new

      expect(backup_code_config.mfa_enabled?).to eq true
    end
  end

  describe 'selection_presenters' do
    it 'returns an array containing the presenter' do
      backup_code_config = BackupCodeConfiguration.new

      expect(backup_code_config.selection_presenters.count).to eq 1
    end
  end

  describe 'friendly_name' do
    it 'returns a friendly name' do
      backup_code_config = BackupCodeConfiguration.new

      expect(backup_code_config.friendly_name).to eq :backup_codes
    end
  end
end
