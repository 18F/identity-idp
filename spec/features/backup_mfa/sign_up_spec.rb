require 'rails_helper'

shared_examples 'setting up backup mfa on sign up' do
  it 'requires backup mfa on direct sign up' do
    user = create(:user, :unconfirmed)
    confirm_last_user
    fill_in 'password_form_password', with: 'salty pickles'
    click_button t('forms.buttons.continue')

    choose_and_confirm_mfa

    click_continue
    expect_back_mfa_setup_to_be_required

    expect(page).to have_current_path(account_path)
    expect(page).to have_content(t('titles.account'))
    expect(user.reload.encrypted_recovery_code_digest).to be_empty
  end

  it 'requires backup mfa on sp sign up' do
    user = visit_idp_from_sp_and_sign_up
    choose_and_confirm_mfa

    click_continue
    expect_back_mfa_setup_to_be_required

    expect(page).to have_current_path(sign_up_completed_path)

    click_button t('forms.buttons.continue')

    expect(current_url).to start_with('http://localhost:7654/auth/result')
    expect(user.reload.encrypted_recovery_code_digest).to be_empty
  end

  def expect_back_mfa_setup_to_be_required
    expect(page).to have_current_path(two_factor_options_path)
    expect(page).to have_content t('two_factor_authentication.two_factor_recovery_choice')

    visit account_path

    expect(page).to have_current_path(two_factor_options_path)
    expect(page).to have_content t('two_factor_authentication.two_factor_recovery_choice')

    select_2fa_option('phone')
    fill_in 'user_phone_form[phone]', with: '202-555-1111'
    click_send_security_code
    fill_in_code_with_last_phone_otp
    click_submit_default
  end

  def visit_idp_from_sp_and_sign_up
    email = Faker::Internet.safe_email
    visit_idp_from_sp_with_loa1(:oidc)
    confirm_email_and_password(email)
    User.find_with_email(email)
  end

  def first_factor_enabled_message(device)
    dmsg = t("two_factor_authentication.devices.#{device}")
    t('two_factor_authentication.first_factor_enabled', device: dmsg)
  end
end

feature 'backup mfa setup on sign up' do
  include SamlAuthHelper
  include WebAuthnHelper

  context 'sms sign up' do
    def choose_and_confirm_mfa
      select_2fa_option('phone')
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default
      :phone
    end

    it_behaves_like 'setting up backup mfa on sign up'
  end

  context 'voice sign up' do
    def choose_and_confirm_mfa
      select_2fa_option(:phone)
      select_phone_delivery_option(:voice)
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default
      :phone
    end

    it_behaves_like 'setting up backup mfa on sign up'
  end

  context 'totp sign up' do
    def choose_and_confirm_mfa
      select_2fa_option('auth_app')
      fill_in :code, with: totp_secret_from_page
      click_submit_default
      :auth_app
    end

    def totp_secret_from_page
      secret = find('#qr-code').text
      generate_totp_code(secret)
    end

    it_behaves_like 'setting up backup mfa on sign up'
  end

  context 'piv/cac sign up' do
    def choose_and_confirm_mfa
      set_up_2fa_with_piv_cac
      :piv_cac
    end

    it_behaves_like 'setting up backup mfa on sign up'
  end

  context 'webauthn sign up' do
    before do
      mock_webauthn_setup_challenge
    end

    def choose_and_confirm_mfa
      select_2fa_option('webauthn')
      fill_in_nickname_and_click_continue
      mock_press_button_on_hardware_key_on_setup
      :webauthn
    end

    it_behaves_like 'setting up backup mfa on sign up'
  end
end
