require 'rails_helper'

RSpec.describe 'Remembering a webauthn device' do
  include WebAuthnHelper

  before do
    allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(1000)
  end

  let(:user) { create(:user, :fully_registered) }

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
        check t('forms.messages.remember_device')
        mock_successful_webauthn_authentication { click_webauthn_authenticate_button }
        first(:button, t('links.sign_out')).click
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

        first(:button, t('links.sign_out')).click
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
        first(:button, t('links.sign_out')).click
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
          :platform_authenticator,
          user: user,
          credential_id: credential_id,
          credential_public_key: credential_public_key,
        )
      end

      def remember_device_and_sign_out_user
        mock_setup_eligible_user_device
        mock_webauthn_verification_challenge
        sign_in_user(user)
        check t('forms.messages.remember_device')
        mock_successful_webauthn_authentication { click_webauthn_authenticate_button }
        first(:button, t('links.sign_out')).click
        user
      end

      it_behaves_like 'remember device'
    end

    context 'sign up' do
      before do
        allow(IdentityConfig.store).
          to receive(:show_unsupported_passkey_platform_authentication_setup).
          and_return(true)
      end

      def click_2fa_option(option)
        find("label[for='two_factor_options_form_selection_#{option}']").click
      end

      def remember_device_and_sign_out_user
        mock_setup_eligible_user_device
        mock_webauthn_setup_challenge
        user = sign_up_and_set_password
        user.password = Features::SessionHelper::VALID_PASSWORD

        # webauthn option is hidden in browsers that don't support it
        select_2fa_option('webauthn_platform', visible: :all)
        check t('forms.messages.remember_device')
        mock_press_button_on_hardware_key_on_setup

        expect(page).to_not have_button(t('mfa.skip'))

        click_link t('mfa.add')

        expect(page).to have_current_path(authentication_methods_setup_path)

        click_2fa_option('phone')

        click_continue

        expect(page).
          to have_content t('headings.add_info.phone')

        expect(current_path).to eq phone_setup_path

        fill_in 'new_phone_form_phone', with: '703-555-1212'
        click_send_one_time_code

        fill_in_code_with_last_phone_otp
        click_submit_default

        first(:button, t('links.sign_out')).click
        user
      end

      it_behaves_like 'remember device'
    end

    context 'update webauthn' do
      def remember_device_and_sign_out_user
        mock_setup_eligible_user_device
        mock_webauthn_setup_challenge
        sign_in_and_2fa_user(user)
        visit account_two_factor_authentication_path
        first(:link, t('account.index.webauthn_add'), href: webauthn_setup_path).click
        fill_in_nickname_and_click_continue
        check t('forms.messages.remember_device')
        mock_press_button_on_hardware_key_on_setup
        expect(page).to have_current_path(account_two_factor_authentication_path)
        first(:button, t('links.sign_out')).click
        user
      end

      it_behaves_like 'remember device'
    end
  end
end
