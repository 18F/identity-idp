require 'rails_helper'

feature 'Multi Two Factor Authentication' do
  before do
    allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return(true)
    allow(IdentityConfig.store).to receive(:kantara_2fa_phone_restricted).and_return(true)
  end

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
      click_send_security_code

      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq backup_code_setup_path

      click_continue

      expect(page).to have_link(t('forms.backup_code.download'))

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
      click_send_security_code

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

      expect(page).to have_link(t('forms.backup_code.download'))

      click_continue

      expect(page).to have_content(t('notices.backup_codes_configured'))

      expect(page).to have_current_path(
        auth_method_confirmation_path,
      )

      click_button t('mfa.skip')

      expect(current_path).to eq account_path
    end

    scenario 'user can select 1 MFA methods and cancels selecting second mfa' do
      sign_in_before_2fa

      expect(current_path).to eq authentication_methods_setup_path

      click_2fa_option('backup_code')

      click_continue

      expect(current_path).to eq backup_code_setup_path

      click_continue

      expect(page).to have_link(t('forms.backup_code.download'))

      click_continue

      expect(page).to have_content(t('notices.backup_codes_configured'))

      expect(page).to have_current_path(
        auth_method_confirmation_path,
      )

      click_link t('mfa.add')

      expect(page).to have_current_path(second_mfa_setup_path)

      click_link t('links.cancel')

      expect(page).to have_current_path(account_path)
    end
  end

  scenario 'redirects to the second_mfa path with an error' do
    sign_in_before_2fa

    expect(current_path).to eq authentication_methods_setup_path

    click_2fa_option('backup_code')

    click_continue

    expect(current_path).to eq backup_code_setup_path

    click_continue

    expect(page).to have_link(t('forms.backup_code.download'))

    click_continue

    expect(page).to have_content(t('notices.backup_codes_configured'))

    expect(page).to have_current_path(
      auth_method_confirmation_path,
    )

    click_link t('mfa.add')

    expect(page).to have_current_path(second_mfa_setup_path)

    click_continue

    expect(page).
      to have_content(t('errors.two_factor_auth_setup.must_select_additional_option'))
  end

  describe 'user attempts to submit with only the phone MFA method selected', js: true do
    before do
      sign_in_before_2fa
      click_2fa_option('phone')
      click_on t('forms.buttons.continue')
    end

    scenario 'redirects to the two_factor path with an error and phone option selected' do
      expect(page).
      to have_content(t('errors.two_factor_auth_setup.must_select_additional_option'))
      expect(
        URI.parse(current_url).path + '#' + URI.parse(current_url).fragment,
      ).to eq authentication_methods_setup_path(anchor: 'select_phone')
    end

    scenario 'clears the error when another mfa method is selected' do
      click_2fa_option('backup_code')
      expect(page).
         to_not have_content(t('errors.two_factor_auth_setup.must_select_additional_option'))
    end

    scenario 'clears the error when phone mfa method is unselected' do
      click_2fa_option('phone')
      expect(page).
        to_not have_content(t('errors.two_factor_auth_setup.must_select_additional_option'))
    end
  end

  def click_2fa_option(option)
    find("label[for='two_factor_options_form_selection_#{option}']").click
  end
end
