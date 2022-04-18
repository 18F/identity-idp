require 'rails_helper'

feature 'Multi Two Factor Authentication' do
  before do
    allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return(true)
  end

  describe 'When the user has not set up 2FA' do
    scenario 'user can set up 2 MFA methods properly' do
      sign_in_before_2fa

      expect(current_path).to eq two_factor_options_path

      click_2fa_option('phone')
      click_2fa_option('backup_code')

      click_continue

      expect(page).
        to have_content t('titles.phone_setup')

      expect(current_path).to eq phone_setup_path

      fill_in 'new_phone_form_phone', with: '703-555-1212'
      click_send_security_code

      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path(
        auth_method_confirmation_path(next_setup_choice: 'backup_code'),
      )

      click_link t('multi_factor_authentication.add')

      expect(current_path).to eq backup_code_setup_path

      click_continue

      expect(page).to have_link(t('forms.backup_code.download'))

      click_continue

      expect(page).to have_content(t('notices.backup_codes_configured'))
      expect(current_path).to eq account_path
    end

    scenario 'user can select 2 MFA methods and complete 1 and skip one' do
      sign_in_before_2fa

      expect(current_path).to eq two_factor_options_path

      click_2fa_option('phone')
      click_2fa_option('backup_code')

      click_continue

      expect(page).
       to have_content t('titles.phone_setup')

      expect(current_path).to eq phone_setup_path

      fill_in 'new_phone_form_phone', with: '703-555-1212'
      click_send_security_code

      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path(
        auth_method_confirmation_path(next_setup_choice: 'backup_code'),
      )

      click_button t('multi_factor_authentication.skip')

      expect(current_path).to eq account_path
    end
  end

  def click_2fa_option(option)
    find("label[for='two_factor_options_form_selection_#{option}']").click
  end
end
