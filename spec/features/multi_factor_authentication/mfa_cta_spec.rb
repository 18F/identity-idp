require 'rails_helper'

feature 'mfa cta banner' do
  include DocAuthHelper
  include SamlAuthHelper

  context 'When multiple factor authentication feature is disabled' do
    it 'does not display a banner as the feature is disabled' do
      visit_idp_from_sp_with_ial1(:oidc)
      user = sign_up_and_set_password
      select_2fa_option('backup_code')
      click_continue

      expect(MfaPolicy.new(user).multiple_factors_enabled?).to eq false
      expect(page).to have_current_path(sign_up_completed_path)
      expect(page).not_to have_content(t('mfa.second_method_warning.text'))
    end
  end

  describe 'multiple MFA handling' do
    it 'displays a banner after configuring a single MFA method' do
      visit_idp_from_sp_with_ial1(:oidc)
      user = sign_up_and_set_password
      select_2fa_option('backup_code')
      click_continue

      click_button t('mfa.skip')
      expect(page).to have_current_path(sign_up_completed_path)
      expect(MfaPolicy.new(user).multiple_factors_enabled?).to eq false
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
      set_up_mfa_with_backup_codes
      expect(page).to have_current_path(sign_up_completed_path)
      expect(page).not_to have_content(t('mfa.second_method_warning.text'))
    end

    it 'redirects user to select additional authentication methods' do
      visit_idp_from_sp_with_ial1(:oidc)
      sign_up_and_set_password
      check t('two_factor_authentication.two_factor_choice_options.backup_code')
      click_continue

      set_up_mfa_with_backup_codes
      click_button t('mfa.skip')
      click_link(t('mfa.second_method_warning.link'))
      expect(page).to have_current_path(second_mfa_setup_path)
    end
  end
end
