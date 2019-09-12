require 'rails_helper'

feature 'success message after first MFA setup' do
  context 'the user is setting up TOTP as first MFA method' do
    it 'shows the MFA setup success screen upon completion' do
      sign_up_and_set_password
      set_up_2fa_with_authenticator_app

      expect(page).to have_content(
        t(
          'headings.mfa_success',
          method: t('two_factor_authentication.devices.auth_app'),
        ),
      )
    end

    it 'redirects to the add another method page after continuing' do
      sign_up_and_set_password
      set_up_2fa_with_authenticator_app

      click_continue

      expect(page).to have_content(
        t('two_factor_authentication.two_factor_recovery_choice'),
      )
    end
  end

  context 'the user is setting up TOTP as the second MFA method' do
    it 'does not show the MFA setup success screen upon completion' do
      sign_up_and_set_password
      set_up_2fa_with_valid_phone

      click_continue

      set_up_2fa_with_authenticator_app

      expect(page).to have_current_path account_path
    end
  end

  context 'the user is adding phone after setting up an account' do
    it 'does not show the MFA setup success screen' do
      user = create(:user, :signed_up)
      phone = '+1 (973) 973-9730'

      sign_in_live_with_2fa(user)

      click_on t('account.index.phone_add')
      fill_in :user_phone_form_phone, with: phone
      click_continue
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path account_path
    end
  end

  context 'the user has only set up their first method' do
    before do
      user = create(:user, :with_phone)
      signin(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
    end

    it 'shows success page before redirecting them to setup screen' do
      expect(page).to have_current_path two_factor_options_success_path
      click_continue
      expect(page).to have_current_path two_factor_options_path
    end
  end
end
