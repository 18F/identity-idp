require 'rails_helper'

feature 'webauthn sign up' do
  include OidcAuthHelper
  include WebAuthnHelper

  let!(:user) { sign_up_and_set_password }

  def visit_webauthn_setup
    # webauthn option is hidden in browsers that don't support it
    select_2fa_option('webauthn', visible: :all)
  end

  def expect_webauthn_setup_success
    expect(page).to have_content(t('notices.webauthn_configured'))
    expect(page).to have_current_path(account_path)
  end

  def expect_webauthn_setup_error
    expect(page).to have_content t('errors.webauthn_setup.general_error')
    expect(page).to have_current_path(authentication_methods_setup_path)
  end

  it_behaves_like 'webauthn setup'

  describe 'AAL3 setup' do
    it 'marks the session AAL3 on setup and does not require authentication' do
      mock_webauthn_setup_challenge

      visit_idp_from_ial1_oidc_sp_requesting_phishing_resistant(prompt: 'select_account')
      select_2fa_option('webauthn', visible: :all)

      expect(current_path).to eq webauthn_setup_path

      fill_in_nickname_and_click_continue
      mock_press_button_on_hardware_key_on_setup

      expect(current_path).to eq(sign_up_completed_path)
    end
  end
end
