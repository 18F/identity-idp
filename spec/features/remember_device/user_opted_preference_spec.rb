require 'rails_helper'
# rubocop:disable Layout/LineLength

describe 'Unchecking remember device' do
  describe '2fa setup' do
    context 'when the 2fa is totp' do
      before do
        user = sign_in_user

        select_2fa_option('auth_app')

        secret = find('#qr-code').text
        fill_in t('forms.totp_setup.totp_step_1'), with: 'App'
        fill_in 'code', with: generate_totp_code(secret)
        uncheck 'remember_device'

        click_button 'Submit'

        first(:link, t('links.sign_out')).click
        sign_in_user(user)
      end

      it 'requires the user to 2fa again and has an unchecked remember device checkbox upon sign in' do
        expect(current_url).to include('/login/two_factor/authenticator')
        expect(page).to have_unchecked_field('remember_device')
      end
    end

    context 'when the 2fa is webauthn' do
      include WebAuthnHelper

      before do
        user = sign_in_user
        mock_webauthn_setup_challenge
        select_2fa_option('webauthn', visible: :all)

        allow(WebauthnSetupForm).to receive(:domain_name).and_return('localhost:3000')

        uncheck(:remember_device)
        fill_in_nickname_and_click_continue

        mock_press_button_on_hardware_key_on_setup
        click_continue

        first(:link, t('links.sign_out')).click
        sign_in_user(user)
      end

      it 'requires the user to 2fa again and has an unchecked remember device checkbox upon sign in' do
        expect(current_url).to include('/login/two_factor/webauthn')
        expect(page).to have_unchecked_field('remember_device')
      end

      it 'has an unchecked remember device checkbox upon next sign in' do
        expect(page).to have_unchecked_field('remember_device')
      end
    end

    context 'when the 2fa is phone' do
      before do
        user = sign_in_user

        select_2fa_option('phone')
        fill_in 'new_phone_form[phone]', with: '202-555-1212'
        click_send_one_time_code
        fill_in_code_with_last_phone_otp

        uncheck 'remember_device'

        click_submit_default

        first(:link, t('links.sign_out')).click
        sign_in_user(user)
      end

      it 'requires the user to 2fa again and has an unchecked remember device checkbox upon sign in' do
        expect(current_url).to include('login/two_factor/sms')
        expect(page).to have_unchecked_field('remember_device')
      end
    end
  end

  describe '2fa verification' do
    context 'when the 2fa is totp' do
      let(:user) { create(:user, :signed_up, :with_authentication_app) }

      before do
        sign_in_user(user)
        fill_in :code, with: generate_totp_code(user.auth_app_configurations.first.otp_secret_key)
        uncheck t('forms.messages.remember_device')
        click_submit_default
        first(:link, t('links.sign_out')).click
        sign_in_user(user)
      end

      it 'requires the user to 2fa again and has an unchecked remember device checkbox upon sign in' do
        expect(current_url).to include('/login/two_factor/authenticator')
        expect(page).to have_unchecked_field('remember_device')
      end
    end

    context 'when the 2fa is webauthn' do
      include WebAuthnHelper

      let(:user) { create(:user, :signed_up) }

      before do
        create(
          :webauthn_configuration,
          user: user,
          credential_id: credential_id,
          credential_public_key: credential_public_key,
        )
        allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
        mock_webauthn_verification_challenge
        sign_in_user(user)
        mock_press_button_on_hardware_key_on_verification
        uncheck(:remember_device)
        click_button t('forms.buttons.continue')
        first(:link, t('links.sign_out')).click

        sign_in_user(user)
      end

      it 'requires the user to 2fa again and has an unchecked remember device checkbox upon sign in' do
        expect(current_url).to include('login/two_factor/webauthn')
        expect(page).to have_unchecked_field('remember_device')
      end
    end

    context 'when the 2fa is phone' do
      let(:user) { user_with_2fa }

      before do
        sign_in_user(user)
        uncheck t('forms.messages.remember_device')
        fill_in_code_with_last_phone_otp
        click_submit_default
        first(:link, t('links.sign_out')).click

        sign_in_user(user)
      end

      it 'requires the user to 2fa again and has an unchecked remember device checkbox upon sign in' do
        expect(current_url).to include('login/two_factor/sms')
        expect(page).to have_unchecked_field('remember_device')
      end
    end
  end
end
# rubocop:enable Layout/LineLength
