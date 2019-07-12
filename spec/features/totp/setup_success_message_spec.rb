require 'rails_helper'

feature 'success message for TOTP setup' do
  context 'the user is setting up TOTP as first MFA method' do
    it 'shows the fist MFA setup success method' do
      sign_up_and_set_password
      set_up_2fa_with_authenticator_app

      click_continue

      expect(page).to_not have_content(t('notices.totp_configured'))
    end
  end

  context 'the user is setting up TOTP as the second MFA method' do
    it 'shows the TOTP setup success message' do
      sign_up_and_set_password
      set_up_2fa_with_valid_phone

      click_continue

      set_up_2fa_with_authenticator_app

      expect(page).to have_content(t('notices.totp_configured'))
      expect(page).to_not have_content(
        t(
          'two_factor_authentication.first_factor_enabled',
          device: t('two_factor_authentication.devices.auth_app'),
        ),
      )
    end
  end

  context 'the user is adding TOTP after setting up an account' do
    it 'shows the TOTP setup success message' do
      user = create(:user, :signed_up)

      sign_in_live_with_2fa(user)

      click_link t('forms.buttons.enable'), href: authenticator_setup_url
      secret = find('#qr-code').text
      fill_in 'code', with: generate_totp_code(secret)
      click_button 'Submit'

      expect(page).to have_content(t('notices.totp_configured'))
      expect(page).to_not have_content(
        t(
          'two_factor_authentication.first_factor_enabled',
          device: t('two_factor_authentication.devices.auth_app'),
        ),
      )
    end
  end
end
