require 'rails_helper'

RSpec.feature 'webauthn sign up' do
  include OidcAuthHelper
  include WebAuthnHelper

  let!(:user) { sign_up_and_set_password }

  def visit_webauthn_setup
    # webauthn option is hidden in browsers that don't support it
    select_2fa_option('webauthn', visible: :all)
  end

  def expect_webauthn_setup_success
    expect(page).to have_content(t('notices.webauthn_configured'))
    expect(page).to have_current_path(auth_method_confirmation_path)
  end

  def expect_webauthn_setup_error
    expect(page).to have_content t(
      'errors.webauthn_setup.general_error_html',
      link_html: t('errors.webauthn_setup.additional_methods_link'),
    )
    expect(page).to have_current_path(webauthn_setup_path)
  end

  it_behaves_like 'webauthn setup'

  describe 'AAL3 setup' do
    it 'marks the session AAL3 on setup and does not require authentication' do
      mock_webauthn_setup_challenge

      visit_idp_from_ial1_oidc_sp_requesting_phishing_resistant(prompt: 'select_account')
      select_2fa_option('webauthn', visible: :all)

      expect(page).to have_current_path webauthn_setup_path

      fill_in_nickname_and_click_continue
      mock_press_button_on_hardware_key_on_setup
      skip_second_mfa_prompt

      expect(page).to have_current_path(sign_up_completed_path)
    end
  end

  describe 'account creation passkey prompt' do
    context 'when feature flag is enabled' do
      let!(:user) do
        allow(FeatureManagement).to receive(:account_creation_passkey_auto_prompt_enabled?)
          .and_return(true)
        allow_any_instance_of(Users::TwoFactorAuthenticationSetupController)
          .to receive(:ab_test_bucket)
          .with(:PASSKEY_UPSELL)
          .and_return(:auto_passkey_prompt)
        user = sign_up
        set_hidden_field('platform_authenticator_available', 'true')
        set_password(user)
      end

      it 'redirects new user to webauthn platform setup page' do
        expect(page).to have_current_path(webauthn_setup_path(platform: true, auto_trigger: true))
      end

      it 'lets the user go back to mfa selection without auto redirecting again' do
        click_on t('two_factor_authentication.choose_another_option')

        expect(page).to have_current_path(authentication_methods_setup_path)
      end
    end

    context 'when feature flag is disabled' do
      let!(:user) do
        allow(FeatureManagement).to receive(:account_creation_passkey_auto_prompt_enabled?)
          .and_return(false)
        sign_up_and_set_password
      end

      it 'redirects new user to MFA selection page' do
        expect(page).to have_current_path(authentication_methods_setup_path)
      end
    end
  end
end
