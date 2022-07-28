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
    it 'is falsey if there is no backup code configuration event' do
      backup_code_config = BackupCodeConfiguration.new

      expect(backup_code_config.mfa_enabled?).to be_falsey
    end

    it 'is truthy if there is a backup code configuration event' do
      user = User.new
      user.save
      BackupCodeGenerator.new(user).create

      user.backup_code_configurations.each do |backup_code_config|
        expect(backup_code_config.mfa_enabled?).to be_truthy
      end
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

  describe 'will_save_change_to_code?' do
    it 'returns false if code did not change' do
      backup_code_config = BackupCodeConfiguration.new

      expect(backup_code_config.will_save_change_to_code?).to eq false
    end

    it 'returns true if code changed' do
      backup_code_config = BackupCodeConfiguration.new
      backup_code_config.code_cost = IdentityConfig.store.backup_code_cost
      backup_code_config.code_salt = 'aaa'
      backup_code_config.code = 'foo'

      expect(backup_code_config.will_save_change_to_code?).to eq true
    end
  end

  describe '.find_with_code' do
    let(:user) { create(:user) }

    it 'returns the code' do
      codes = BackupCodeGenerator.new(user).create
      first_code = codes.first

      expect(BackupCodeConfiguration.find_with_code(code: first_code, user_id: user.id)).to be
    end

    it 'does not return the code with a wrong user id' do
      codes = BackupCodeGenerator.new(user).create
      first_code = codes.first

      expect(BackupCodeConfiguration.find_with_code(code: first_code, user_id: 1234)).to be_nil
    end

    it 'finds codes via salted_code_fingerprint' do
      codes = BackupCodeGenerator.new(user).create
      first_code = codes.first

      backup_code = BackupCodeConfiguration.find_with_code(code: first_code, user_id: user.id)
      expect(backup_code).to be
    end

    it 'finds codes if they have different salts and costs from each other' do
      user.backup_code_configurations.create!(
        code_cost: '10$8$4$',
        code_salt: 'abcdefg',
        code: '1234',
      )

      user.backup_code_configurations.create!(
        code_cost: '100$8$4$',
        code_salt: 'hijklmno',
        code: '5678',
      )

      expect(BackupCodeConfiguration.find_with_code(code: '1234', user_id: user.id)).to be
      expect(BackupCodeConfiguration.find_with_code(code: '5678', user_id: user.id)).to be

      expect(BackupCodeConfiguration.find_with_code(code: '9999', user_id: user.id)).to_not be
    end

    def save_and_find(find:, save: 'just-some-not-null-value')
      user.backup_code_configurations.build(
        code_cost: '10$8$4$',
        code_salt: 'abcdefg',
        code: save,
      ).save!

      BackupCodeConfiguration.find_with_code(code: find, user_id: user.id)
    end

    it 'base32 crockford normalizes codes when searching' do
      expect(save_and_find(save: 'abcd-0000-i1i1', find: 'ABCD-oOoO-1111')).to be
    end

    it 'finds codes if they were generated the old way (with SecureRandom.hex)' do
      code = SecureRandom.hex(3 * 4 / 2)
      expect(save_and_find(save: code, find: code)).to be
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

    it 'returns only one selection presenter if multiple backup code configurations' do
      bc = BackupCodeConfiguration.new
      bc2 = BackupCodeConfiguration.new
      set = BackupCodeConfiguration.selection_presenters([bc, bc2])

      expect(set.first).instance_of? TwoFactorAuthentication::BackupCodeSelectionPresenter.class
      expect(set.size).to eq(1)
    end
  end
end
