require 'rails_helper'

describe 'Remembering a webauthn device' do
  include WebAuthnHelper

  before do
    allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(1000)
  end

  let(:user) { create(:user, :signed_up) }

  context 'roaming authenticator' do
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
        check t('forms.messages.remember_device')
        click_button t('forms.buttons.continue')
        first(:link, t('links.sign_out')).click
        user
      end

      it_behaves_like 'remember device'
    end

    context 'sign up' do
      def remember_device_and_sign_out_user
        mock_webauthn_setup_challenge
        user = sign_up_and_set_password
        user.password = Features::SessionHelper::VALID_PASSWORD

        # webauthn option is hidden in browsers that don't support it
        select_2fa_option('webauthn', visible: :all)
        fill_in_nickname_and_click_continue
        check t('forms.messages.remember_device')
        mock_press_button_on_hardware_key_on_setup
        skip_second_mfa_prompt

        first(:link, t('links.sign_out')).click
        user
      end

      it_behaves_like 'remember device'
    end

    context 'update webauthn' do
      def remember_device_and_sign_out_user
        mock_webauthn_setup_challenge
        sign_in_and_2fa_user(user)
        visit account_two_factor_authentication_path

        first(:link, t('account.index.webauthn_add'), href: webauthn_setup_path).click
        fill_in_nickname_and_click_continue
        check t('forms.messages.remember_device')
        mock_press_button_on_hardware_key_on_setup
        expect(page).to have_current_path(account_two_factor_authentication_path)
        first(:link, t('links.sign_out')).click
        user
      end

      it_behaves_like 'remember device'
    end
  end

  context 'platform authenticator' do
    context 'sign in' do
      before do
        create(
          :webauthn_configuration,
          user: user,
          platform_authenticator: true,
          credential_id: credential_id,
          credential_public_key: credential_public_key,
        )
      end

      def remember_device_and_sign_out_user
        mock_webauthn_verification_challenge
        sign_in_user(user)
        mock_press_button_on_hardware_key_on_verification
        check t('forms.messages.remember_device')
        click_button t('forms.buttons.continue')
        first(:link, t('links.sign_out')).click
        user
      end

      it_behaves_like 'remember device'
    end

    context 'sign up' do
      def remember_device_and_sign_out_user
        mock_webauthn_setup_challenge
        user = sign_up_and_set_password
        user.password = Features::SessionHelper::VALID_PASSWORD

        # webauthn option is hidden in browsers that don't support it
        select_2fa_option('webauthn', visible: :all)
        fill_in_nickname_and_click_continue
        check t('forms.messages.remember_device')
        mock_press_button_on_hardware_key_on_setup
        skip_second_mfa_prompt

        first(:link, t('links.sign_out')).click
        user
      end

      it_behaves_like 'remember device'
    end

    context 'update webauthn' do
      def remember_device_and_sign_out_user
        mock_webauthn_setup_challenge
        sign_in_and_2fa_user(user)
        visit account_two_factor_authentication_path
        first(:link, t('account.index.webauthn_add'), href: webauthn_setup_path).click
        fill_in_nickname_and_click_continue
        check t('forms.messages.remember_device')
        mock_press_button_on_hardware_key_on_setup
        expect(page).to have_current_path(account_two_factor_authentication_path)
        first(:link, t('links.sign_out')).click
        user
      end

      it_behaves_like 'remember device'
    end
  end
end
