require 'rails_helper'

describe 'Remembering a webauthn device' do
  include WebAuthnHelper

  before do
    allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
    allow(Figaro.env).to receive(:otp_delivery_blocklist_maxretry).and_return('1000')
  end

  let(:user) { create(:user, :signed_up) }

  context 'sign in' do
    before do
      create(
        :webauthn_configuration,
        user: user,
        credential_id: credential_id,
        credential_public_key: credential_public_key,
      )
    end

    def remember_device_and_sign_out_user
      mock_webauthn_verification_challenge
      sign_in_user(user)
      mock_press_button_on_hardware_key_on_verification
      check :remember_device
      click_button t('forms.buttons.continue')
      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'sign up with remember_device last' do
    def remember_device_and_sign_out_user
      mock_webauthn_setup_challenge
      user = sign_up_and_set_password
      user.password = Features::SessionHelper::VALID_PASSWORD

      select_2fa_option('phone')
      fill_in :user_phone_form_phone, with: '2025551313'
      click_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default

      click_continue

      select_2fa_option('webauthn')
      fill_in_nickname_and_click_continue
      check :remember_device
      mock_press_button_on_hardware_key_on_setup

      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'sign up with remember_device and phone as 2nd MFA' do
    def remember_device_and_sign_out_user
      mock_webauthn_setup_challenge
      user = sign_up_and_set_password
      user.password = Features::SessionHelper::VALID_PASSWORD

      select_2fa_option('webauthn')
      fill_in_nickname_and_click_continue
      check :remember_device
      mock_press_button_on_hardware_key_on_setup

      click_continue

      select_2fa_option('phone')
      fill_in :user_phone_form_phone, with: '2025551313'
      click_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default

      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'sign up with remember_device and totp as 2nd MFA' do
    def remember_device_and_sign_out_user
      mock_webauthn_setup_challenge
      user = sign_up_and_set_password
      user.password = Features::SessionHelper::VALID_PASSWORD

      select_2fa_option('webauthn')
      fill_in_nickname_and_click_continue
      check :remember_device
      mock_press_button_on_hardware_key_on_setup

      click_continue

      select_2fa_option('auth_app')
      secret = find('#qr-code').text
      fill_in 'code', with: generate_totp_code(secret)
      click_button 'Submit'

      click_continue

      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'sign up with remember_device and webauthn as 2nd MFA' do
    def remember_device_and_sign_out_user
      mock_webauthn_setup_challenge
      user = sign_up_and_set_password
      user.password = Features::SessionHelper::VALID_PASSWORD

      select_2fa_option('webauthn')
      fill_in_nickname_and_click_continue
      check :remember_device
      mock_press_button_on_hardware_key_on_setup

      click_continue

      mock_webauthn_setup_challenge
      select_2fa_option('webauthn')
      fill_in_nickname_and_click_continue(nickname: 'my2ndkey')
      mock_press_button_on_hardware_key_on_setup

      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'sign up with remember_device and backup codes as 2nd MFA' do
    def remember_device_and_sign_out_user
      mock_webauthn_setup_challenge
      user = sign_up_and_set_password
      user.password = Features::SessionHelper::VALID_PASSWORD

      select_2fa_option('webauthn')
      fill_in_nickname_and_click_continue
      check :remember_device
      mock_press_button_on_hardware_key_on_setup

      click_continue

      select_2fa_option('backup_code')
      click_continue

      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'update webauthn' do
    def remember_device_and_sign_out_user
      mock_webauthn_setup_challenge
      sign_in_and_2fa_user(user)
      click_link t('account.index.webauthn_add'), href: webauthn_setup_path
      fill_in_nickname_and_click_continue
      check :remember_device
      mock_press_button_on_hardware_key_on_setup
      expect(page).to have_current_path(account_path)
      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end
end
