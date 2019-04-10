# Once personal keys are entirely retired and the backup mfa method policy
# is in place, this spec file can become the spec file for the backup code
# policy

require 'rails_helper'

shared_examples 'not issuing a personal key on sign up' do
  it 'does not issue a personal key on direct sign up' do
    user = sign_up_and_set_password
    choose_and_confirm_mfa

    expect(page).to have_current_path(two_factor_options_path)

    select_2fa_option('sms')
    fill_in 'user_phone_form[phone]', with: '202-555-1111'
    click_send_security_code
    click_submit_default

    expect(page).to have_current_path(account_path)
    expect(page).to have_content(t('titles.account'))
    expect(user.reload.encrypted_recovery_code_digest).to be_empty
  end

  it 'does not issue a personal key on sp sign up' do
    user = visit_idp_from_sp_and_sign_up
    choose_and_confirm_mfa

    expect(page).to have_current_path(two_factor_options_path)

    select_2fa_option('sms')
    fill_in 'user_phone_form[phone]', with: '202-555-1111'
    click_send_security_code
    click_submit_default

    expect(page).to have_current_path(sign_up_completed_path)

    click_button t('forms.buttons.continue')

    expect(current_url).to start_with('http://localhost:7654/auth/result')
    expect(user.reload.encrypted_recovery_code_digest).to be_empty
  end

  def visit_idp_from_sp_and_sign_up
    email = Faker::Internet.safe_email
    visit openid_connect_authorize_path(
      client_id: 'urn:gov:gsa:openidconnect:sp:server',
      response_type: 'code',
      acr_values: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: SecureRandom.hex,
      prompt: 'select_account',
      nonce: SecureRandom.hex,
    )
    click_on t('sign_up.registrations.create_account')
    fill_in :user_email, with: email
    click_submit_default
    open_last_email
    click_email_link_matching(/confirmation_token/)
    fill_in 'password_form_password', with: 'salty pickles'
    click_button t('forms.buttons.continue')
    User.find_with_email(email)
  end
end

feature 'signing up without being issues a personal key' do
  include WebAuthnHelper

  before do
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    allow(Figaro.env).to receive(:personal_key_assignment_disabled).and_return('true')
  end

  context 'sms sign up' do
    def choose_and_confirm_mfa
      select_2fa_option('sms')
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
      click_submit_default
    end

    it_behaves_like 'not issuing a personal key on sign up'
  end

  context 'voice sign up' do
    def choose_and_confirm_mfa
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      select_2fa_option('voice')
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
      click_submit_default
    end

    it_behaves_like 'not issuing a personal key on sign up'
  end

  context 'totp sign up' do
    def choose_and_confirm_mfa
      select_2fa_option('auth_app')
      fill_in :code, with: totp_secret_from_page
      click_submit_default
    end

    def totp_secret_from_page
      secret = find('#qr-code').text
      generate_totp_code(secret)
    end

    it_behaves_like 'not issuing a personal key on sign up'
  end

  context 'piv/cac sign up' do
    before do
      allow(PivCacService).to receive(:piv_cac_available_for_email?).and_return(true)
    end

    def choose_and_confirm_mfa
      set_up_2fa_with_piv_cac
    end

    it_behaves_like 'not issuing a personal key on sign up'
  end

  context 'webauthn sign up' do
    before do
      mock_webauthn_setup_challenge
    end

    def choose_and_confirm_mfa
      select_2fa_option('webauthn')
      fill_in_nickname_and_click_continue
      mock_press_button_on_hardware_key_on_setup
      click_button t('forms.buttons.continue')
    end

    it_behaves_like 'not issuing a personal key on sign up'
  end

  context 'backup code sign up' do
    def choose_and_confirm_mfa
      select_2fa_option('backup_code')
      click_continue
    end

    it_behaves_like 'not issuing a personal key on sign up'
  end
end
