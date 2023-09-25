require 'rails_helper'

RSpec.feature 'at second mfa setup' do
  include DocAuthHelper
  include SamlAuthHelper
  include WebAuthnHelper

  describe 'adding a phone as a second mfa' do
    it 'at setup, phone as second MFA show a cancel link that returns to mfa setup' do
      allow(IdentityConfig.store).to receive(:platform_auth_set_up_enabled).and_return(true)
      allow(IdentityConfig.store).
        to receive(:show_unsupported_passkey_platform_authentication_setup).
        and_return(true)

      sign_up_and_set_password
      mock_webauthn_setup_challenge
      select_2fa_option('webauthn_platform', visible: :all)

      click_continue
      fill_in_nickname_and_click_continue
      mock_press_button_on_hardware_key_on_setup

      click_link t('mfa.add')

      select_2fa_option('phone')
      click_continue

      fill_in :new_phone_form_phone, with: '3015551212'
      click_send_one_time_code

      expect(page).to have_link(
        t('links.cancel'),
        href: authentication_methods_setup_path,
      )
    end
  end
end
