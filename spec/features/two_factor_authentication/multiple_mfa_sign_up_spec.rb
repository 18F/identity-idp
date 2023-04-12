require 'rails_helper'

feature 'Multi Two Factor Authentication' do
  describe 'When the user has not set up 2FA' do
    scenario 'user can set up 2 MFA methods properly' do
      sign_in_before_2fa

      expect(current_path).to eq authentication_methods_setup_path

      click_2fa_option('phone')
      click_2fa_option('backup_code')

      click_continue

      expect(page).
        to have_content t('titles.phone_setup')

      expect(current_path).to eq phone_setup_path

      fill_in 'new_phone_form_phone', with: '703-555-1212'
      click_send_one_time_code

      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq backup_code_setup_path

      click_continue

      expect(page).to have_link(t('components.download_button.label'))

      click_continue

      expect(page).to have_content(t('notices.backup_codes_configured'))
      expect(current_path).to eq account_path
    end

    scenario 'user can select 2 MFA methods and then chooses another method during' do
      sign_in_before_2fa

      expect(current_path).to eq authentication_methods_setup_path

      click_2fa_option('phone')
      click_2fa_option('backup_code')

      click_continue

      expect(page).
        to have_content t('titles.phone_setup')

      expect(current_path).to eq phone_setup_path

      fill_in 'new_phone_form_phone', with: '703-555-1212'
      click_send_one_time_code

      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq backup_code_setup_path

      click_link t('two_factor_authentication.choose_another_option')

      expect(page).to have_current_path(second_mfa_setup_path)

      select_2fa_option('auth_app')
      fill_in t('forms.totp_setup.totp_step_1'), with: 'App'

      secret = find('#qr-code').text
      totp = generate_totp_code(secret)

      fill_in :code, with: totp
      check t('forms.messages.remember_device')
      click_submit_default

      expect(current_path).to eq account_path
    end

    scenario 'user can select 1 MFA methods and will be prompted to add another method' do
      sign_in_before_2fa

      expect(current_path).to eq authentication_methods_setup_path

      click_2fa_option('backup_code')

      click_continue

      expect(current_path).to eq backup_code_setup_path

      click_continue

      expect(page).to have_link(t('components.download_button.label'))

      click_continue

      expect(page).to have_content(t('notices.backup_codes_configured'))

      expect(page).to have_current_path(
        auth_method_confirmation_path,
      )

      click_button t('mfa.skip')

      expect(current_path).to eq account_path
    end

    scenario 'user can select 1 MFA methods and skips selecting second mfa' do
      sign_in_before_2fa

      expect(current_path).to eq authentication_methods_setup_path

      click_2fa_option('backup_code')

      click_continue

      expect(current_path).to eq backup_code_setup_path

      click_continue

      expect(page).to have_link(t('components.download_button.label'))

      click_continue

      expect(page).to have_content(t('notices.backup_codes_configured'))

      expect(page).to have_current_path(
        auth_method_confirmation_path,
      )

      click_link t('mfa.add')

      expect(page).to have_current_path(second_mfa_setup_path)

      click_link t('mfa.skip')

      expect(page).to have_current_path(account_path)
    end
  end

  def click_2fa_option(option)
    find("label[for='two_factor_options_form_selection_#{option}']").click
  end
end
