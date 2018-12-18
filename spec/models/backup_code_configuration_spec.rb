require 'rails_helper'

RSpec.describe BackupCodeConfiguration, type: :model do
  describe 'Methods' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to respond_to(:mfa_enabled?) }
    it { is_expected.to respond_to(:selection_presenters) }
    it { is_expected.to respond_to(:friendly_name) }
  end

  describe 'self.unused' do
    it 'count is zero' do
      expect(BackupCodeConfiguration.unused.count).to eq 0
    end
  end

  describe 'mfa_enabled?' do
    it 'is set to true' do
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

  describe 'code_in_database' do
    it 'returns nil' do
      backup_code_config = BackupCodeConfiguration.new

      expect(backup_code_config.code_in_database).to eq nil
    end
  end

  describe 'will_save_change_to_code?' do
    it 'returns false' do
      backup_code_config = BackupCodeConfiguration.new

      expect(backup_code_config.will_save_change_to_code?).to eq false
    end
  end

  describe 'find_with_code' do
    it 'returns code' do
      user = User.new
      user.save
      codes = BackupCodeGenerator.new(user).generate_new_codes
      first_code = codes.first
      backup_code = BackupCodeConfiguration.find_with_code(code: first_code, user_id: user.id)
      expect(backup_code.code).to eq first_code
    end
  end

  describe 'self.selection_presenters(set)' do
    it 'returns [] if set is []' do
      set = BackupCodeConfiguration.selection_presenters([])

      expect(set).to eq []
    end

    it 'returns a selection presenter' do
      bc = BackupCodeConfiguration.new
      set = BackupCodeConfiguration.selection_presenters([bc])

      expect(set.first).instance_of? TwoFactorAuthentication::BackupCodeSelectionPresenter.class
    end
  end
end
