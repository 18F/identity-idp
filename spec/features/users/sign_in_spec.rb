require 'rails_helper'

feature 'Sign in' do
  include SessionTimeoutWarningHelper
  include ActionView::Helpers::DateHelper
  include PersonalKeyHelper
  include SamlAuthHelper
  include SpAuthHelper
  include IdvHelper

  scenario 'user cannot sign in if not registered' do
    signin('test@example.com', 'Please123!')
    link_url = new_user_password_url

    expect(page).
      to have_link t('devise.failure.not_found_in_database_link_text', href: link_url)
  end

  it 'does not throw an exception if the email contains invalid bytes' do
    signin("test@\xFFbar\xF8.com", 'Please123!')
    expect(page).to have_content 'Bad request'
  end

  scenario 'user cannot sign in with wrong email' do
    user = create(:user)
    signin('invalid@email.com', user.password)
    link_url = new_user_password_url

    expect(page).
      to have_link t('devise.failure.invalid_link_text', href: link_url)
  end

  scenario 'user cannot sign in with empty email' do
    signin('', 'foo')

    link_url = new_user_password_url

    expect(page).
      to have_link t('devise.failure.not_found_in_database_link_text', href: link_url)
  end

  scenario 'user cannot sign in with empty password' do
    signin('test@example.com', '')

    link_url = new_user_password_url

    expect(page).
      to have_link t('devise.failure.not_found_in_database_link_text', href: link_url)
  end

  scenario 'user cannot sign in with wrong password' do
    user = create(:user)
    signin(user.email, 'invalidpass')
    link_url = new_user_password_url

    expect(page).
      to have_link t('devise.failure.invalid_link_text', href: link_url)
  end

  scenario 'user can see and use password visibility toggle', js: true do
    visit new_user_session_path

    find('.checkbox').click

    expect(page).to have_css('input.password[type="text"]')
  end

  scenario 'user session expires in amount of time specified by Devise config' do
    sign_in_and_2fa_user

    visit account_path
    expect(current_path).to eq account_path

    Timecop.travel(Devise.timeout_in + 1.minute)

    visit account_path
    expect(current_path).to eq root_path

    Timecop.return
  end

  scenario 'user session cookie has no explicit expiration time (dies with browser exit)' do
    sign_in_and_2fa_user

    expect(session_cookie.expires).to be_nil
  end

  context 'session approaches timeout', js: true do
    before :each do
      allow(Figaro.env).to receive(:session_check_frequency).and_return('1')
      allow(Figaro.env).to receive(:session_check_delay).and_return('2')
      allow(Figaro.env).to receive(:session_timeout_warning_seconds).
        and_return(Devise.timeout_in.to_s)

      sign_in_and_2fa_user
      visit root_path
    end

    scenario 'user sees warning before session times out' do
      expect(page).to have_css('#session-timeout-msg')

      time1 = page.text[/14:5[0-9]/]
      expect(page).to have_content(time1)
      sleep(1)
      time2 = page.text[/14:5[0-9]/]
      expect(time2).to be < time1
    end

    scenario 'user can continue browsing' do
      find_link(t('notices.timeout_warning.signed_in.continue')).click

      expect(current_path).to eq account_path
    end

    scenario 'user has option to sign out' do
      click_link(t('notices.timeout_warning.signed_in.sign_out'))

      expect(page).to have_content t('devise.sessions.signed_out')
      expect(current_path).to eq new_user_session_path
    end
  end

  context 'user only signs in via email and password', js: true do
    it 'displays the session timeout warning with partially signed in copy' do
      allow(Figaro.env).to receive(:session_check_frequency).and_return('1')
      allow(Figaro.env).to receive(:session_check_delay).and_return('2')
      allow(Figaro.env).to receive(:session_timeout_warning_seconds).
        and_return(Devise.timeout_in.to_s)

      user = create(:user, :signed_up)
      sign_in_user(user)
      visit user_two_factor_authentication_path

      expect(page).to have_css('#session-timeout-msg')
      expect(page).to have_content(t('notices.timeout_warning.partially_signed_in.continue'))
      expect(page).to have_content(t('notices.timeout_warning.partially_signed_in.sign_out'))
    end
  end

  context 'signed out' do
    it 'refreshes the current page after session expires', js: true do
      allow(Devise).to receive(:timeout_in).and_return(1)

      visit sign_up_email_path(request_id: '123abc')
      fill_in 'Email', with: 'test@example.com'

      expect(page).to have_content(
        t('notices.session_cleared', minutes: Figaro.env.session_timeout_in_minutes)
      )
      expect(page).to have_field('Email', with: '')
      expect(current_url).to match Regexp.escape(sign_up_email_path(request_id: '123abc'))
    end

    it 'does not refresh the page after the session expires', js: true do
      allow(Devise).to receive(:timeout_in).and_return(60)

      visit root_path
      expect(page).to_not have_content(
        t('notices.session_cleared', minutes: Figaro.env.session_timeout_in_minutes)
      )
    end
  end

  context 'signing back in after session timeout length' do
    before do
      ActionController::Base.allow_forgery_protection = true
    end

    after do
      ActionController::Base.allow_forgery_protection = false
    end

    it 'fails to sign in the user, with CSRF error' do
      user = sign_in_and_2fa_user
      click_link(t('links.sign_out'), match: :first)

      Timecop.travel(Devise.timeout_in + 1.minute) do
        expect(page).to_not have_content(t('forms.buttons.continue'))

        # Redis doesn't respect Timecop so expire session manually.
        session_store.send(:destroy_session_from_sid, session_cookie.value)

        fill_in_credentials_and_submit(user.email, user.password)
        expect(page).to have_content t('errors.invalid_authenticity_token')

        fill_in_credentials_and_submit(user.email, user.password)
        expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
      end
    end

    it 'refreshes the page (which clears the form) and notifies the user', js: true do
      allow(Devise).to receive(:timeout_in).and_return(1)
      user = create(:user)
      visit root_path
      fill_in 'Email', with: user.email
      fill_in 'Password', with: user.password

      expect(page).to have_content(
        t('notices.session_cleared', minutes: Figaro.env.session_timeout_in_minutes)
      )
      expect(find_field('Email').value).to be_blank
      expect(find_field('Password').value).to be_blank
    end
  end

  describe 'session timeout configuration' do
    it 'uses delay and warning settings whose sum is a multiple of 60' do
      expect((start + warning) % 60).to eq 0
    end

    it 'uses frequency and warning settings whose sum is a multiple of 60' do
      expect((frequency + warning) % 60).to eq 0
    end
  end

  context 'user attempts too many concurrent sessions' do
    scenario 'redirects to home page with error' do
      user = user_with_2fa

      perform_in_browser(:one) do
        sign_in_live_with_2fa(user)

        expect(current_path).to eq account_path
      end

      perform_in_browser(:two) do
        sign_in_live_with_2fa(user)

        expect(current_path).to eq account_path
      end

      perform_in_browser(:one) do
        visit account_path

        expect(current_path).to eq new_user_session_path
        expect(page).to have_content(t('devise.failure.session_limited'))
      end
    end
  end

  context 'attribute_encryption_key is changed but queue does not contain any previous keys' do
    it 'throws an exception and does not overwrite User email' do
      email = 'test@example.com'
      password = 'salty pickles'

      create(:user, :signed_up, email: email, password: password)

      user = User.find_with_email(email)
      encrypted_email = user.encrypted_email

      rotate_attribute_encryption_key_with_invalid_queue

      expect { signin(email, password) }.
        to raise_error Pii::EncryptionError, 'unable to decrypt attribute with any key'

      user = User.find_with_email(email)
      expect(user.encrypted_email).to eq encrypted_email
    end
  end

  context 'KMS is on and user enters incorrect password' do
    it 'redirects to root_path with user-friendly error message, not a 500 error' do
      allow(FeatureManagement).to receive(:use_kms?).and_return(true)
      stub_aws_kms_client_invalid_ciphertext
      allow(SessionEncryptorErrorHandler).to receive(:call)

      user = create(:user)
      signin(user.email, 'invalid')

      link_url = new_user_password_url

      expect(page).
        to have_link t('devise.failure.invalid_link_text', href: link_url)
      expect(current_path).to eq root_path
    end
  end

  context 'invalid request_id' do
    it 'allows the user to sign in and does not try to redirect to any SP' do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      user = create(:user, :signed_up)

      visit new_user_session_path(request_id: 'invalid')
      fill_in_credentials_and_submit(user.email, user.password)
      click_submit_default

      expect(current_path).to eq account_path
    end
  end

  context 'CSRF error' do
    it 'redirects to sign in page with flash message' do
      user = create(:user, :signed_up)
      visit new_user_session_path(request_id: '123')
      allow_any_instance_of(Users::SessionsController).
        to receive(:create).and_raise(ActionController::InvalidAuthenticityToken)

      fill_in_credentials_and_submit(user.email, user.password)

      expect(current_url).to eq new_user_session_url(request_id: '123')
      expect(page).to have_content t('errors.invalid_authenticity_token')
    end
  end

  context 'visiting a page that requires authentication while signed out' do
    it 'redirects to sign in page with relevant flash message' do
      visit account_path

      expect(current_path).to eq new_user_session_path
      expect(page).to have_content(t('devise.failure.unauthenticated'))
    end
  end

  it_behaves_like 'signing in with the site in Spanish', :saml
  it_behaves_like 'signing in with the site in Spanish', :oidc

  context 'user signs in with Voice OTP delivery preference to an unsupported country' do
    it 'falls back to SMS with an error message' do
      allow(SmsOtpSenderJob).to receive(:perform_later)
      allow(VoiceOtpSenderJob).to receive(:perform_later)
      user = create(:user, :signed_up, phone: '+91 1234567890', otp_delivery_preference: 'voice')
      signin(user.email, user.password)

      expect(VoiceOtpSenderJob).to_not have_received(:perform_later)
      expect(SmsOtpSenderJob).to have_received(:perform_later)
      expect(page).
        to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false))
      expect(page).to have_content t(
        'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
        location: 'India'
      )
      expect(user.reload.otp_delivery_preference).to eq 'sms'
    end
  end

  context 'user tries to visit /login/two_factor/voice with an unsupported phone' do
    it 'displays an error message but does not send an SMS' do
      allow(SmsOtpSenderJob).to receive(:perform_later)
      allow(VoiceOtpSenderJob).to receive(:perform_later)
      user = create(:user, :signed_up, phone: '+91 1234567890', otp_delivery_preference: 'sms')
      signin(user.email, user.password)
      visit login_two_factor_path(otp_delivery_preference: 'voice', reauthn: false)

      expect(VoiceOtpSenderJob).to_not have_received(:perform_later)
      expect(SmsOtpSenderJob).to have_received(:perform_later).exactly(:once)
      expect(page).
        to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false))
      expect(page).to have_content t(
        'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
        location: 'India'
      )
      expect(user.reload.otp_delivery_preference).to eq 'sms'
    end
  end

  context 'user tries to visit /otp/send with voice delivery to an unsupported phone' do
    it 'displays an error message but does not send an SMS' do
      allow(SmsOtpSenderJob).to receive(:perform_later)
      allow(VoiceOtpSenderJob).to receive(:perform_later)
      user = create(:user, :signed_up, phone: '+91 1234567890', otp_delivery_preference: 'sms')
      signin(user.email, user.password)
      visit otp_send_path(
        otp_delivery_selection_form: { otp_delivery_preference: 'voice', resend: true }
      )

      expect(VoiceOtpSenderJob).to_not have_received(:perform_later)
      expect(SmsOtpSenderJob).to have_received(:perform_later).exactly(:once)
      expect(page).
        to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms'))
      expect(page).to have_content t(
        'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
        location: 'India'
      )
      expect(user.reload.otp_delivery_preference).to eq 'sms'
    end
  end

  context 'user with voice delivery preference visits /otp/send' do
    it 'displays an error message but does not send an SMS' do
      allow(SmsOtpSenderJob).to receive(:perform_later)
      allow(VoiceOtpSenderJob).to receive(:perform_later)
      user = create(:user, :signed_up, phone: '+91 1234567890', otp_delivery_preference: 'voice')
      signin(user.email, user.password)
      visit otp_send_path(
        otp_delivery_selection_form: { otp_delivery_preference: 'voice', resend: true }
      )

      expect(VoiceOtpSenderJob).to_not have_received(:perform_later)
      expect(SmsOtpSenderJob).to have_received(:perform_later).exactly(:once)
      expect(page).
        to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms'))
      expect(page).to have_content t(
        'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
        location: 'India'
      )
      expect(user.reload.otp_delivery_preference).to eq 'sms'
    end
  end

  it_behaves_like 'signing in as LOA1 with personal key', :saml
  it_behaves_like 'signing in as LOA1 with personal key', :oidc
  it_behaves_like 'signing in as LOA3 with personal key', :saml
  it_behaves_like 'signing in as LOA3 with personal key', :oidc
  it_behaves_like 'signing in with wrong credentials', :saml
  it_behaves_like 'signing in with wrong credentials', :oidc

  context 'user signs in with personal key, visits account page before viewing new key' do
    # this can happen if you submit the personal key form multiple times quickly
    it 'redirects to the personal key page' do
      user = create(:user, :signed_up)
      old_personal_key = PersonalKeyGenerator.new(user).create
      signin(user.email, user.password)
      click_link t('devise.two_factor_authentication.personal_key_fallback.link')
      enter_personal_key(personal_key: old_personal_key)
      click_submit_default
      visit account_path

      expect(page).to have_current_path(manage_personal_key_path)

      click_acknowledge_personal_key

      expect(page).to have_current_path(account_path)
    end
  end
end
