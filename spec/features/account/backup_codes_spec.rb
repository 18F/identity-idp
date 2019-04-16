require 'rails_helper'

feature 'Backup codes' do
  before do
    sign_in_and_2fa_user(user)
  end

  context 'with backup codes' do
    let(:user) { create(:user, :with_backup_code, :with_piv_or_cac) }

    it 'backup code generated and can be regenerated' do
      expect(page).to have_content(t('account.index.backup_codes_exist'))
      old_backup_code = user.backup_code_configurations.sample
      click_link t('forms.backup_code.regenerate'), href: backup_code_regenerate_path
      click_link t('account.index.backup_code_confirm_regenerate')
      expect(BackupCodeConfiguration.where(id: old_backup_code.id).any?).to eq(false)
      expect(current_path).to eq backup_code_setup_path
    end
  end

  context 'without backup codes just phone' do
    let(:user) { create(:user, :signed_up) }

    it 'does not show backup code section' do
      expect(page).to have_content(t('account.index.backup_codes_no_exist'))
    end
  end

  context 'user clicks generate backup codes' do
    let(:user) { create(:user, :with_piv_or_cac) }

    it 'user can click generate backup codes' do
      click_link t('forms.backup_code.generate'), href: backup_code_setup_path
    end
  end
end
