require 'rails_helper'

RSpec.feature 'mfa cta banner', allowed_extra_analytics: [:*] do
  include DocAuthHelper
  include SamlAuthHelper

  describe 'multiple MFA handling' do
    it 'displays a banner after configuring a single MFA method' do
      visit_idp_from_sp_with_ial1(:oidc)
      user = sign_up_and_set_password
      select_2fa_option('phone')
      click_continue

      fill_in :new_phone_form_phone, with: '3015551212'
      click_send_one_time_code

      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_content(t('notices.phone_confirmed'))

      click_button t('mfa.skip')
      expect(page).to have_current_path(sign_up_completed_path)
      expect(MfaPolicy.new(user).multiple_factors_enabled?).to eq false
      expect(page).to have_content(t('mfa.second_method_warning.text'))
    end

    it 'displays a banner after confirming that backup codes are saved' do
      visit_idp_from_sp_with_ial1(:oidc)
      user = sign_up_and_set_password
      select_2fa_option('backup_code')
      expect(MfaPolicy.new(user).multiple_factors_enabled?).to eq false
      expect(page).to have_current_path(confirm_backup_codes_path)

      click_on t('forms.buttons.continue')

      expect(page).to have_content(t('mfa.second_method_warning.text'))
    end

    it 'does not display a banner after configuring multiple MFA methods' do
      visit_idp_from_sp_with_ial1(:oidc)
      sign_up_and_set_password
      check t('two_factor_authentication.two_factor_choice_options.phone')
      check t('two_factor_authentication.two_factor_choice_options.backup_code')
      click_continue

      expect(page).to have_current_path(phone_setup_path)
      set_up_mfa_with_valid_phone

      expect(page).to have_current_path(backup_code_setup_path)
      click_continue
      expect(page).to have_current_path(sign_up_completed_path)
      expect(page).not_to have_content(t('mfa.second_method_warning.text'))
    end

    it 'redirects user to select additional authentication methods' do
      visit_idp_from_sp_with_ial1(:oidc)
      sign_up_and_set_password
      check t('two_factor_authentication.two_factor_choice_options.backup_code')

      set_up_mfa_with_backup_codes

      expect(page).to have_current_path(confirm_backup_codes_path)
      click_link(t('mfa.add'))
      expect(page).to have_current_path(authentication_methods_setup_path)
    end
  end
end
