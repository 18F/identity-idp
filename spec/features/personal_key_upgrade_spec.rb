require 'rails_helper'

describe 'signing in with an MFA method and upgrading personal key to another method' do
  include WebAuthnHelper

  let(:user) { create(:user, :with_phone, :with_personal_key) }

  scenario 'setting up a phone' do
    visit_idp_from_sp
    sign_in_live_with_2fa(user)

    expect_personal_key_upgrade_screen

    select_2fa_option :phone
    fill_in :new_phone_form_phone, with: '2255555000'
    click_send_security_code
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect_user_to_go_to_sp
  end

  scenario 'setting up a authentication app' do
    visit_idp_from_sp
    sign_in_live_with_2fa(user)

    expect_personal_key_upgrade_screen

    select_2fa_option :auth_app
    secret = find('#qr-code').text
    fill_in :code, with: generate_totp_code(secret)
    click_submit_default

    expect_user_to_go_to_sp
  end

  scenario 'setting up a webauthn key' do
    allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
    mock_webauthn_setup_challenge

    visit_idp_from_sp
    sign_in_live_with_2fa(user)

    expect_personal_key_upgrade_screen

    select_2fa_option :webauthn
    fill_in_nickname_and_click_continue
    mock_press_button_on_hardware_key_on_setup

    expect_user_to_go_to_sp
  end

  scenario 'setting up backup codes' do
    visit_idp_from_sp
    sign_in_live_with_2fa(user)

    expect_personal_key_upgrade_screen

    select_2fa_option :backup_code
    click_continue

    expect_user_to_go_to_sp
  end

  scenario 'signing in with a remembered device and setting up another method' do
    # First, sign in and remember device
    user = create(:user, :with_phone, :with_personal_key)
    sign_in_user(user)
    fill_in_code_with_last_phone_otp
    check :remember_device
    click_submit_default
    click_on '‹ Cancel sign in'
    visit root_path

    visit_idp_from_sp
    sign_in_user(user)

    expect_personal_key_upgrade_screen

    select_2fa_option :backup_code
    click_continue

    expect_user_to_go_to_sp
  end

  def visit_idp_from_sp
    visit openid_connect_authorize_path(
      client_id: 'urn:gov:gsa:openidconnect:sp:server',
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: SecureRandom.hex,
      prompt: 'select_account',
      nonce: SecureRandom.hex,
    )
  end

  def expect_personal_key_upgrade_screen
    expect(page).to have_content(
      t('two_factor_authentication.two_factor_choice_retire_personal_key'),
    )
    expect(page).to have_current_path(two_factor_options_path)
  end

  def expect_user_to_go_to_sp
    expect(page).to have_content(t('help_text.requested_attributes.intro_html', sp: 'Test SP'))
    expect(page).to have_current_path(sign_up_completed_path)

    click_agree_and_continue

    expect(current_url).to start_with('http://localhost:7654/auth/result')
  end
end
