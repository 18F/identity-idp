require 'rails_helper'

feature 'Sign Up' do
  include SamlAuthHelper

  context 'confirmation token error message does not persist on success' do
    scenario 'with no or invalid token' do
      visit sign_up_create_email_confirmation_url(confirmation_token: '')
      expect(page).to have_content t('errors.messages.confirmation_invalid_token')

      sign_up

      expect(page).not_to have_content t('errors.messages.confirmation_invalid_token')
    end
  end

  context 'user cancels sign up on email screen' do
    before do
      visit sign_up_email_path
      click_on t('links.cancel')
    end

    it 'redirects user to the home page' do
      expect(current_path).to eq root_path
    end
  end

  context 'user cancels on the enter password screen', email: true do
    before(:each) do
      confirm_email('test@test.com')
      click_on t('links.cancel_account_creation')
    end

    it 'sends them to the cancel page' do
      expect(current_path).to eq sign_up_cancel_path
    end

    it 'does not display a link to get back to their account' do
      expect(page).to_not have_content t('links.back_to_account')
    end
  end

  context 'user cancels on 1st MFA screen', email: true do
    before(:each) do
      confirm_email('test@test.com')
      submit_form_with_valid_password
      click_on t('links.cancel_account_creation')
    end

    it 'sends them to the cancel page' do
      expect(current_path).to eq sign_up_cancel_path
    end

    it 'does not display a link to get back to their account' do
      expect(page).to_not have_content t('links.back_to_account')
    end
  end

  context 'user cancels on 2nd MFA screen', email: true do
    before(:each) do
      confirm_email('test@test.com')
      submit_form_with_valid_password
      set_up_2fa_with_valid_phone
      click_on t('links.cancel_account_creation')
    end

    it 'sends them to the cancel page' do
      expect(current_path).to eq sign_up_cancel_path
    end

    it 'does not display a link to get back to their account' do
      expect(page).to_not have_content t('links.back_to_account')
    end
  end

  context 'user cancels with language preference set' do
    it 'redirects user to the translated home page' do
      visit sign_up_email_path(locale: 'es')
      click_on t('links.cancel')
      expect(current_path).to eq '/es'
    end
  end

  scenario 'renders an error when the telephony gem responds with an error' do
    telephony_error = Telephony::TelephonyError.new('error message')

    allow(Telephony).to receive(:send_confirmation_otp).and_raise(telephony_error)
    sign_up_and_set_password
    select_2fa_option('phone')
    expect(page).to_not have_content t('two_factor_authentication.otp_make_default_number.title')

    fill_in 'user_phone_form_phone', with: '202-555-1212'
    click_send_security_code

    expect(current_path).to eq(phone_setup_path)
    expect(page).to have_content(telephony_error.friendly_message)
  end

  context 'with js', js: true do
    context 'user enters their email as their password', email: true do
      it 'treats it as a weak password' do
        email = 'test@test.com'

        visit sign_up_email_path
        submit_form_with_valid_email(email)
        click_confirmation_link_in_email(email)

        fill_in 'Password', with: email
        expect(page).to have_content('Very weak')
      end
    end
  end

  context 'user accesses password screen with already confirmed token', email: true do
    it 'returns them to the home page' do
      create(:user, :signed_up, confirmation_token: 'foo')

      visit sign_up_enter_password_path(confirmation_token: 'foo', request_id: 'bar')

      expect(page).to have_current_path(root_path)

      action = t('devise.confirmations.sign_in')
      expect(page).
        to have_content t('devise.confirmations.already_confirmed', action: action)
    end
  end

  context 'user accesses password screen with invalid token', email: true do
    it 'returns them to the resend email confirmation page' do
      visit sign_up_enter_password_path(confirmation_token: 'foo', request_id: 'bar')

      expect(page).to have_current_path(sign_up_email_resend_path)

      expect(page).
        to have_content t('errors.messages.confirmation_invalid_token')
    end
  end

  context "user A is signed in and accesses password creation page with User B's token" do
    it "redirects to User A's account page" do
      create(:user, :signed_up, email: 'userb@test.com', confirmation_token: 'foo')
      sign_in_and_2fa_user
      visit sign_up_enter_password_path(confirmation_token: 'foo')

      expect(page).to have_current_path(account_path)
      expect(page).to_not have_content 'userb@test.com'
    end
  end

  it_behaves_like 'creating an account with the site in Spanish', :saml
  it_behaves_like 'creating an account with the site in Spanish', :oidc

  it_behaves_like 'creating an account using authenticator app for 2FA', :saml
  it_behaves_like 'creating an account using authenticator app for 2FA', :oidc

  it_behaves_like 'creating an account using PIV/CAC for 2FA', :saml
  it_behaves_like 'creating an account using PIV/CAC for 2FA', :oidc

  it 'allows a user to choose TOTP as 2FA method during sign up' do
    sign_in_user
    set_up_2fa_with_authenticator_app
    click_continue
    set_up_2fa_with_backup_code

    expect(page).to have_current_path account_path
  end

  it 'does not bypass 2FA when accessing authenticator_setup_path if the user is 2FA enabled' do
    user = create(:user, :signed_up)
    sign_in_user(user)
    visit authenticator_setup_path

    expect(page).
      to have_current_path login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false)
  end

  it 'prompts to sign in when accessing authenticator_setup_path before signing in' do
    create(:user, :signed_up)
    visit authenticator_setup_path

    expect(page).to have_current_path root_path
  end

  context 'CSP whitelists recaptcha for style-src' do
    scenario 'recaptcha is disabled' do
      allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(false)

      visit sign_up_email_path

      expect(page.response_headers['Content-Security-Policy']).
        to(include('style-src \'self\''))
    end

    scenario 'recaptcha is enabled' do
      allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(true)

      visit sign_up_email_path

      expect(page.response_headers['Content-Security-Policy']).
        to(include('style-src \'self\' \'unsafe-inline\''))
    end
  end

  describe 'user is partially authenticated and phone 2fa is not configured' do
    context 'with piv/cac enabled' do
      let(:user) do
        create(:user, :with_piv_or_cac, :with_backup_code)
      end

      before(:each) do
        sign_in_user(user)
      end

      scenario 'can not access phone_setup' do
        expect(page).to have_current_path login_two_factor_piv_cac_path
        visit phone_setup_path
        expect(page).to have_current_path login_two_factor_piv_cac_path
      end

      scenario 'can not access phone_setup via login/two_factor/sms' do
        expect(page).to have_current_path login_two_factor_piv_cac_path
        visit login_two_factor_path(otp_delivery_preference: :sms)
        expect(page).to have_current_path login_two_factor_piv_cac_path
      end

      scenario 'can not access phone_setup via login/two_factor/voice' do
        expect(page).to have_current_path login_two_factor_piv_cac_path
        visit login_two_factor_path(otp_delivery_preference: :voice)
        expect(page).to have_current_path login_two_factor_piv_cac_path
      end
    end
  end
end
