require 'rails_helper'

RSpec.feature 'Backup codes', allowed_extra_analytics: [:*] do
  before do
    sign_in_and_2fa_user(user)
    visit account_two_factor_authentication_path
  end

  context 'with backup codes' do
    let(:user) { create(:user, :fully_registered, :with_piv_or_cac, :with_backup_code) }

    it 'backup code generated and can be regenerated' do
      expect(page).to have_content(t('account.index.backup_codes_exist'))
      old_backup_code = user.backup_code_configurations.sample
      click_link t('forms.backup_code.regenerate'), href: backup_code_regenerate_path
      click_on t('account.index.backup_code_confirm_regenerate')

      expect(BackupCodeConfiguration.where(id: old_backup_code.id).any?).to eq(false)

      click_continue

      expect(page).to have_content(t('notices.backup_codes_configured'))
      expect(page).to have_current_path(account_two_factor_authentication_path)
    end

    it 'allows you to delete the backup codes' do
      expect(page).to have_content(t('account.index.backup_codes_exist'))
      click_link t('forms.buttons.delete'), href: backup_code_delete_path

      expect(page).to have_current_path(backup_code_delete_path)

      click_button t('account.index.backup_code_confirm_delete')

      expect(page).to have_content(t('notices.backup_codes_deleted'))
      expect(page).to have_current_path(account_two_factor_authentication_path)
    end
  end

  context 'without backup codes just phone' do
    let(:user) { create(:user, :with_phone, :with_piv_or_cac) }

    it 'does not show backup code section' do
      expect(page).to have_content(t('account.index.backup_codes_no_exist'))
    end
  end

  context 'user clicks generate backup codes' do
    let(:user) { create(:user, :with_phone, :with_piv_or_cac) }

    it 'user can click generate backup codes' do
      click_on t('forms.backup_code.generate')

      expect(page).to have_current_path(backup_code_setup_path)

      generated_at = user.backup_code_configurations.
        order(created_at: :asc).first.created_at.
        in_time_zone('UTC')
      formatted_generated_at = l(generated_at, format: t('time.formats.event_timestamp'))

      expected_message = "#{t('account.index.backup_codes_exist')} #{formatted_generated_at}"

      expect(page).to have_current_path(backup_code_setup_path)
      click_continue

      expect(page).to have_content(t('notices.backup_codes_configured'))
      expect(page).to have_current_path(account_two_factor_authentication_path)

      expect(page).to have_content(expected_message)
    end
  end

  context 'with only backup codes' do
    let(:user) { create(:user, :with_backup_code) }

    it 'the user is not prompted to set up another MFA upon login' do
      expect(current_path).to eq account_two_factor_authentication_path
    end
  end
end
