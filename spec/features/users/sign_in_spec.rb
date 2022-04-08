require 'rails_helper'

feature 'Sign in' do
  before(:all) do
    @original_capyabara_wait = Capybara.default_max_wait_time
    Capybara.default_max_wait_time = 5
  end

  after(:all) do
    Capybara.default_max_wait_time = @original_capyabara_wait
  end

  include SessionTimeoutWarningHelper
  include ActionView::Helpers::DateHelper
  include PersonalKeyHelper
  include SamlAuthHelper
  include SpAuthHelper
  include IdvHelper
  include DocAuthHelper

  scenario 'user signs in as ial1 and does not see ial2 help text' do
    visit_idp_from_sp_with_ial1(:oidc)

    expect(page).to_not have_content t('devise.registrations.start.accordion')
  end

  scenario 'user signs in as ialmax and does not see ial2 help text' do
    visit_idp_from_oidc_sp_with_ialmax

    expect(page).to_not have_content t('devise.registrations.start.accordion')
  end

  scenario 'user signs in as ial2 and does see ial2 help text' do
    visit_idp_from_sp_with_ial2(:oidc)

    expect(page).to have_content t('devise.registrations.start.accordion')
  end

  scenario 'user signs in with loa3 request from oidc sp and does see ial2 help text' do
    visit_idp_from_oidc_sp_with_loa3

    expect(page).to have_content t('devise.registrations.start.accordion')
  end

  scenario 'user signs in with loa3 request from saml sp and does see ial2 help text' do
    visit_idp_from_saml_sp_with_loa3

    expect(page).to have_content t('devise.registrations.start.accordion')
  end

  scenario 'user cannot sign in if not registered' do
    signin('test@example.com', 'Please123!')
    link_url = new_user_password_url

    expect(page).
      to have_link t('devise.failure.not_found_in_database_link_text', href: link_url)
  end

  scenario 'user opts to not add piv/cac card' do
    perform_steps_to_get_to_add_piv_cac_during_sign_up
    click_on t('forms.piv_cac_setup.no_thanks')
    expect(current_path).to eq account_path
  end

  scenario 'user opts to add piv/cac card' do
    perform_steps_to_get_to_add_piv_cac_during_sign_up
    nonce = piv_cac_nonce_from_form_action
    visit_piv_cac_service(
      current_url,
      nonce: nonce,
      dn: 'C=US, O=U.S. Government, OU=DoD, OU=PKI, CN=DOE.JOHN.1234',
      uuid: SecureRandom.uuid,
      subject: 'SomeIgnoredSubject',
    )

    expect(current_path).to eq login_add_piv_cac_success_path
    click_continue
    expect(current_path).to eq sign_up_completed_path
  end

  scenario 'user opts to add piv/cac card but gets an error' do
    perform_steps_to_get_to_add_piv_cac_during_sign_up
    nonce = piv_cac_nonce_from_form_action
    visit_piv_cac_service(
      current_url,
      nonce: nonce,
      dn: 'C=US, O=U.S. Government, OU=DoD, OU=PKI, CN=DOE.JOHN.1234',
      uuid: SecureRandom.uuid,
      error: 'certificate.bad',
      subject: 'SomeIgnoredSubject',
    )

    expect(page).to have_current_path(login_piv_cac_error_path(error: 'certificate.bad'))
  end

  scenario 'user opts to add piv/cac card and has piv cac redirect in CSP' do
    allow(Identity::Hostdata).to receive(:env).and_return('test')
    allow(Identity::Hostdata).to receive(:domain).and_return('example.com')

    perform_steps_to_get_to_add_piv_cac_during_sign_up

    expected_form_action = <<-STR.squish
      form-action https://*.pivcac.test.example.com 'self'
      http://localhost:7654 https://example.com
    STR

    expect(page.response_headers['Content-Security-Policy']).
      to(include(expected_form_action))
  end

  scenario 'user attempts sign in with a PIV/CAC on mobile' do
    allow(BrowserCache).to receive(:parse).and_return(mobile_device)
    visit root_path

    expect(page).to_not have_link t('account.login.piv_cac')
  end

  scenario 'user attempts sign in with the default MFA on mobile and a PIV/CAC configured' do
    allow(BrowserCache).to receive(:parse).and_return(mobile_device)
    sign_in_before_2fa(user_with_piv_cac)

    expect(current_path).to eq(login_otp_path(otp_delivery_preference: :sms))
  end

  scenario 'user attempts sign in with piv/cac with no account then creates account' do
    visit_idp_from_sp_with_ial1(:oidc)
    click_on t('account.login.piv_cac')
    allow(FeatureManagement).to receive(:development_and_identity_pki_disabled?).and_return(false)

    stub_piv_cac_service
    nonce = get_piv_cac_nonce_from_link(find_link(t('forms.piv_cac_login.submit')))
    visit_piv_cac_service(
      current_url,
      nonce: nonce,
      dn: 'C=US, O=U.S. Government, OU=DoD, OU=PKI, CN=DOE.JOHN.1234',
      uuid: SecureRandom.uuid,
      subject: 'SomeIgnoredSubject',
    )

    expect(page).to have_current_path(login_piv_cac_error_path(error: 'user.not_found'))
    visit sign_up_email_path
    email = 'foo@bar.com'
    submit_form_with_valid_email(email)
    click_confirmation_link_in_email(email)
    submit_form_with_valid_password
    expect(page).to have_current_path(two_factor_options_path)

    select_2fa_option('phone')
    fill_in :new_phone_form_phone, with: '2025551314'
    click_send_security_code
    fill_in_code_with_last_phone_otp
    click_submit_default
    click_agree_and_continue
    expect(current_url).to start_with('http://localhost:7654/auth/result')
  end

  scenario 'user cannot sign in with certificate none error' do
    signin_with_piv_error('certificate.none')

    expect(page).to have_current_path(login_piv_cac_error_path(error: 'certificate.none'))
  end

  scenario 'user cannot sign in with certificate not auth cert error' do
    signin_with_piv_error('certificate.not_auth_cert')

    expect(page).to have_current_path(login_piv_cac_error_path(error: 'certificate.not_auth_cert'))
  end

  scenario 'user cannot sign in with an unregistered piv/cac card' do
    signin_with_bad_piv

    expect(page).to have_current_path(login_piv_cac_error_path(error: 'token.bad'))
  end

  it 'does not throw an exception if the email contains invalid bytes' do
    suppress_output do
      signin("test@\xFFbar\xF8.com", 'Please123!')
      expect(page).to have_content 'Bad request'
    end
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

    check t('components.password_toggle.toggle_label')

    expect(page).to have_css('input.password[type="text"]')
  end

  scenario 'user session expires in amount of time specified by Devise config' do
    sign_in_and_2fa_user

    visit account_path
    expect(current_path).to eq account_path

    travel(Devise.timeout_in + 1.minute)

    visit account_path
    expect(current_path).to eq root_path

    travel_back
  end

  scenario 'user session cookie has no explicit expiration time (dies with browser exit)' do
    sign_in_and_2fa_user

    expect(session_cookie.expires).to be_nil
  end

  context 'session approaches timeout', js: true do
    before :each do
      allow(IdentityConfig.store).to receive(:session_check_frequency).and_return(1)
      allow(IdentityConfig.store).to receive(:session_check_delay).and_return(2)
      allow(IdentityConfig.store).to receive(:session_timeout_warning_seconds).
        and_return(Devise.timeout_in)

      sign_in_and_2fa_user
      visit root_path
    end

    scenario 'user sees warning before session times out' do
      expect(page).to have_css('#session-timeout-msg')

      time1 = page.text[/14 minutes and 5[0-9] seconds/]
      sleep(1)
      time2 = page.text[/14 minutes and 5[0-9] seconds/]
      expect(time2).to be < time1
    end

    scenario 'user can continue browsing' do
      find_button(t('notices.timeout_warning.signed_in.continue')).click

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
      allow(IdentityConfig.store).to receive(:session_check_frequency).and_return(1)
      allow(IdentityConfig.store).to receive(:session_check_delay).and_return(2)
      allow(IdentityConfig.store).to receive(:session_timeout_warning_seconds).
        and_return(Devise.timeout_in)

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
      fill_in t('forms.registration.labels.email'), with: 'test@example.com'

      expect(page).to have_content(
        t('notices.session_cleared', minutes: IdentityConfig.store.session_timeout_in_minutes),
        wait: 5,
      )
      expect(page).to have_field(t('forms.registration.labels.email'), with: '')
      expect(current_url).to match Regexp.escape(sign_up_email_path(request_id: '123abc'))
    end

    it 'does not refresh the page after the session expires', js: true do
      allow(Devise).to receive(:timeout_in).and_return(60)

      visit root_path
      expect(page).to_not have_content(
        t('notices.session_cleared', minutes: IdentityConfig.store.session_timeout_in_minutes),
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

      travel(Devise.timeout_in + 1.minute) do
        expect(page).to_not have_content(t('forms.buttons.continue'))

        # Redis doesn't respect ActiveSupport::Testing::TimeHelpers, so expire session manually.
        session_store.send(:destroy_session_from_sid, session_cookie.value)

        fill_in_credentials_and_submit(user.email, user.password)
        expect(page).to have_content t('errors.general')

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
        t('notices.session_cleared', minutes: IdentityConfig.store.session_timeout_in_minutes),
      )
      expect(find_field('Email').value).to be_blank
      expect(find_field('Password').value).to be_blank
    end
  end

  describe 'session timeout configuration' do
    it 'uses delay and warning settings whose sum is a multiple of 60' do
      expect((session_timeout_start + session_timeout_warning) % 60).to eq 0
    end

    it 'uses frequency and warning settings whose sum is a multiple of 60' do
      expect((session_timeout_frequency + session_timeout_warning) % 60).to eq 0
    end
  end

  context 'user attempts too many concurrent sessions' do
    context 'with email and password' do
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

    context 'with piv/cac' do
      scenario 'redirects to home page with error' do
        user = user_with_piv_cac

        perform_in_browser(:one) do
          sign_in_user_with_piv(user)

          expect(current_path).to eq account_path
        end

        perform_in_browser(:two) do
          sign_in_user_with_piv(user)

          expect(current_path).to eq account_path
        end

        perform_in_browser(:one) do
          visit account_path

          expect(current_path).to eq new_user_session_path
          expect(page).to have_content(t('devise.failure.session_limited'))
        end
      end
    end
  end

  context 'attribute_encryption_key is changed but queue does not contain any previous keys' do
    context 'when logging in with email and password' do
      it 'throws an exception and does not overwrite User email' do
        email = 'test@example.com'
        password = 'salty pickles'

        create(:user, :signed_up, email: email, password: password)

        user = User.find_with_email(email)
        encrypted_email = user.encrypted_email

        rotate_attribute_encryption_key_with_invalid_queue

        expect { signin(email, password) }.
          to raise_error Encryption::EncryptionError, 'unable to decrypt attribute with any key'

        user = user.reload
        expect(user.encrypted_email).to eq encrypted_email
      end
    end

    context 'when logging in with piv/cac' do
      it 'does not overwrite User email' do
        email = 'test@example.com'
        password = 'salty pickles'

        create(:user, :signed_up, email: email, password: password)

        user = User.find_with_email(email)
        encrypted_email = user.encrypted_email

        rotate_attribute_encryption_key_with_invalid_queue

        sign_in_user_with_piv(user)

        user = user.reload
        expect(user.encrypted_email).to eq encrypted_email
      end
    end
  end

  context 'KMS is on and user enters incorrect password' do
    it 'redirects to root_path with user-friendly error message, not a 500 error' do
      user = create(:user)
      email = user.email
      allow(FeatureManagement).to receive(:use_kms?).and_return(true)
      stub_aws_kms_client_invalid_ciphertext
      allow(SessionEncryptorErrorHandler).to receive(:call)

      signin(email, 'invalid')

      link_url = new_user_password_url

      expect(page).
        to have_link t('devise.failure.invalid_link_text', href: link_url)
      expect(current_path).to eq root_path
    end
  end

  context 'invalid request_id' do
    it 'allows the user to sign in and does not try to redirect to any SP' do
      user = create(:user, :signed_up)

      visit new_user_session_path(request_id: 'invalid')
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      expect(current_path).to eq account_path
    end

    context 'with email and password' do
      it 'allows the user to sign in and does not try to redirect to any SP' do
        allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
        user = create(:user, :signed_up)

        visit new_user_session_path(request_id: 'invalid')
        fill_in_credentials_and_submit(user.email, user.password)
        click_submit_default

        expect(current_path).to eq account_path
      end
    end

    context 'with piv/cac' do
      it 'allows the user to sign in and does not try to redirect to any SP' do
        user = create(:user, :signed_up, :with_piv_or_cac)

        visit new_user_session_path(request_id: 'invalid')
        signin_with_piv(user)

        expect(current_path).to eq account_path
      end
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
      expect(page).to have_content t('errors.general')
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
    it 'falls back to SMS with an error message if SMS is supported' do
      user = create(
        :user, :signed_up,
        otp_delivery_preference: 'voice', with: { phone: '+61 02 1234 5678' }
      )
      signin(user.email, user.password)

      expect(Telephony::Test::Call.calls.length).to eq(0)
      expect(Telephony::Test::Message.messages.length).to eq(1)
      expect(page).
        to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false))
      expect(page).to have_content t(
        'two_factor_authentication.otp_delivery_preference.voice_unsupported',
        location: 'Australia',
      )
      expect(user.reload.otp_delivery_preference).to eq 'sms'
    end

    it 'shows error message if SMS and Voice are not supported' do
      user = create(
        :user, :signed_up,
        otp_delivery_preference: 'voice', with: { phone: '+213 09 1234 5678' }
      )
      signin(user.email, user.password)

      expect(Telephony::Test::Call.calls.length).to eq(0)
      expect(Telephony::Test::Message.messages.length).to eq(0)
      expect(page).
        to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false))
      expect(page).to have_content t(
        'two_factor_authentication.otp_delivery_preference.voice_unsupported',
        location: 'Algeria',
      )
      expect(user.reload.otp_delivery_preference).to eq 'voice'
    end
  end

  # For these tests, we need to have a country that is supports_sms: true, supports_voice: false
  let(:unsupported_country_phone_number) { '+354 611 1234' }
  let(:unsupported_country_name) { 'Iceland' }

  context 'user tries to visit /login/two_factor/voice with an unsupported phone' do
    it 'displays an error message but does not send another SMS' do
      user = create(
        :user, :signed_up,
        otp_delivery_preference: 'sms', with: { phone: unsupported_country_phone_number }
      )
      signin(user.email, user.password)
      visit login_two_factor_path(otp_delivery_preference: 'voice', reauthn: false)

      expect(Telephony::Test::Call.calls.length).to eq(0)
      expect(Telephony::Test::Message.messages.length).to eq(1)
      expect(page).
        to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false))
      expect(page).to have_content t(
        'two_factor_authentication.otp_delivery_preference.voice_unsupported',
        location: unsupported_country_name,
      )
      expect(user.reload.otp_delivery_preference).to eq 'sms'
    end
  end

  context 'user tries to visit /otp/send with voice delivery to an unsupported phone' do
    it 'displays an error message but does not send another SMS' do
      user = create(
        :user, :signed_up,
        otp_delivery_preference: 'sms', with: { phone: unsupported_country_phone_number }
      )
      signin(user.email, user.password)
      visit otp_send_path(
        otp_delivery_selection_form: { otp_delivery_preference: 'voice', resend: true },
      )

      expect(Telephony::Test::Call.calls.length).to eq(0)
      expect(Telephony::Test::Message.messages.length).to eq(1)
      expect(page).
        to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms'))
      expect(page).to have_content t(
        'two_factor_authentication.otp_delivery_preference.voice_unsupported',
        location: unsupported_country_name,
      )
      expect(user.reload.otp_delivery_preference).to eq 'sms'
    end
  end

  context 'user with voice delivery preference visits /otp/send' do
    it 'displays an error message but does not send another SMS' do
      user = create(
        :user, :signed_up,
        otp_delivery_preference: 'voice', with: { phone: unsupported_country_phone_number }
      )
      signin(user.email, user.password)
      visit otp_send_path(
        otp_delivery_selection_form: { otp_delivery_preference: 'voice', resend: true },
      )

      expect(Telephony::Test::Call.calls.length).to eq(0)
      expect(Telephony::Test::Message.messages.length).to eq(1)
      expect(page).
        to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false))
      expect(page).to have_content t(
        'two_factor_authentication.otp_delivery_preference.voice_unsupported',
        location: unsupported_country_name,
      )
      expect(user.reload.otp_delivery_preference).to eq 'sms'
    end
  end

  it_behaves_like 'signing in as IAL1 with personal key', :saml
  it_behaves_like 'signing in as IAL1 with personal key', :oidc
  it_behaves_like 'signing in as IAL2 with personal key', :saml
  it_behaves_like 'signing in as IAL2 with personal key', :oidc
  it_behaves_like 'signing in as IAL1 with piv/cac', :saml
  it_behaves_like 'signing in as IAL1 with piv/cac', :oidc
  it_behaves_like 'signing in as IAL2 with piv/cac', :saml
  it_behaves_like 'signing in as IAL2 with piv/cac', :oidc
  it_behaves_like 'signing in with wrong credentials', :saml
  it_behaves_like 'signing in with wrong credentials', :oidc

  it_behaves_like 'signing in as proofed account with broken personal key', :saml, sp_ial: 1
  it_behaves_like 'signing in as proofed account with broken personal key', :oidc, sp_ial: 1
  it_behaves_like 'signing in as proofed account with broken personal key', :saml, sp_ial: 2
  it_behaves_like 'signing in as proofed account with broken personal key', :oidc, sp_ial: 2

  context 'user signs in and chooses another authentication method' do
    it 'signs out the user if they choose to cancel' do
      user = create(:user, :signed_up)
      signin(user.email, user.password)
      accept_rules_of_use_and_continue_if_displayed
      click_link t('two_factor_authentication.login_options_link_text')
      click_on t('links.cancel')

      expect(current_path).to eq root_path
      expect(page).to have_content(t('devise.sessions.signed_out'))
    end
  end

  context 'user signs in when accepted_terms_at is out of date', js: true do
    it 'validates terms checkbox and signs in successfully' do
      user = create(:user, :signed_up, accepted_terms_at: nil)
      signin(user.email, user.password)

      click_button t('forms.buttons.continue')
      expect(page).to have_css(':focus[name="rules_of_use_form[terms_accepted]"]', visible: :all)

      check 'rules_of_use_form[terms_accepted]'

      click_button t('forms.buttons.continue')
      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
    end
  end

  context 'user signs in with personal key, visits account page' do
    # this can happen if you submit the personal key form multiple times quickly
    it 'does not redirect to the personal key page' do
      user = create(:user, :signed_up)
      old_personal_key = PersonalKeyGenerator.new(user).create
      signin(user.email, user.password)
      choose_another_security_option('personal_key')
      enter_personal_key(personal_key: old_personal_key)
      click_submit_default
      visit account_path
      expect(page).to have_current_path(account_path)
    end
  end

  context 'user attempts sign in with bad personal key' do
    it 'remains on the login with personal key page' do
      user = create(:user, :signed_up, :with_personal_key)
      signin(user.email, user.password)
      choose_another_security_option('personal_key')
      enter_personal_key(personal_key: 'foo')
      click_submit_default

      expect(page).to have_current_path(login_two_factor_personal_key_path)
      expect(page).to have_content t('two_factor_authentication.invalid_personal_key')
    end
  end

  context 'user is totp_enabled but not phone_enabled' do
    before do
      user = create(:user, :with_authentication_app, :with_backup_code)
      signin(user.email, user.password)
    end

    it 'requires 2FA before allowing access to phone setup form' do
      visit phone_setup_path

      expect(page).to have_current_path login_two_factor_authenticator_path
    end

    it 'does not redirect to phone setup form when visiting /login/two_factor/sms' do
      visit login_two_factor_path(otp_delivery_preference: 'sms')

      expect(page).to have_current_path login_two_factor_authenticator_path
    end

    it 'does not redirect to phone setup form when visiting /login/two_factor/voice' do
      visit login_two_factor_path(otp_delivery_preference: 'voice')

      expect(page).to have_current_path login_two_factor_authenticator_path
    end

    it 'does not display OTP Fallback text and links' do
      expect(page).
        to_not have_content t('two_factor_authentication.phone_fallback.question')
    end
  end

  context 'visiting via SP1, then via SP2, then signing in' do
    it 'redirects to SP2' do
      user = create(:user, :signed_up)
      visit_idp_from_sp_with_ial1(:saml)
      visit_idp_from_sp_with_ial1(:oidc)
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_agree_and_continue

      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end

  context 'a prompt login sp redirects back to auth url immediately after we redirect to them' do
    it 'logs an SP bounce and displays the bounced error screen' do
      user = create(:user, :signed_up)
      visit_idp_from_oidc_sp_with_loa1_prompt_login
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_agree_and_continue

      visit_idp_from_oidc_sp_with_loa1_prompt_login
      expect(current_path).to eq(bounced_path)
    end
  end

  context 'multiple piv cacs' do
    it 'allows you to sign in with either' do
      user = create(:user, :signed_up, :with_piv_or_cac)
      user_id = user.id
      ::PivCacConfiguration.create!(user_id: user_id, x509_dn_uuid: 'foo', name: 'key1')
      ::PivCacConfiguration.create!(user_id: user_id, x509_dn_uuid: 'bar', name: 'key2')

      visit new_user_session_path
      click_on t('account.login.piv_cac')
      fill_in_piv_cac_credentials_and_submit(user, 'foo')

      expect(current_url).to eq account_url

      Capybara.reset_session!

      visit new_user_session_path
      click_on t('account.login.piv_cac')
      fill_in_piv_cac_credentials_and_submit(user, 'bar')

      expect(current_url).to eq account_url
    end
  end

  context 'multiple auth apps' do
    it 'allows you to sign in with either' do
      user = create(:user, :signed_up)
      Db::AuthAppConfiguration.create(user, 'foo', nil, 'foo')
      Db::AuthAppConfiguration.create(user, 'bar', nil, 'bar')

      visit new_user_session_path
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in :code, with: generate_totp_code('foo')
      click_submit_default

      expect(current_url).to eq account_url

      Capybara.reset_session!

      visit new_user_session_path
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in :code, with: generate_totp_code('bar')
      click_submit_default

      expect(current_url).to eq account_url
    end
  end

  context 'oidc sp requests ialmax' do
    it 'returns ial1 info for a non-verified user' do
      user = create(:user, :signed_up)
      visit_idp_from_oidc_sp_with_ialmax
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq sign_up_completed_path
      expect(page).to have_content(user.email)

      click_agree_and_continue

      expect(current_url).to start_with('http://localhost:7654/auth/result')
    end

    it 'returns ial2 info for a verified user' do
      user = create(
        :profile, :active, :verified,
        pii: { first_name: 'John', ssn: '111223333' }
      ).user
      visit_idp_from_oidc_sp_with_ialmax
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq sign_up_completed_path
      expect(page).to have_content('1**-**-***3')

      click_agree_and_continue

      expect(current_url).to start_with('http://localhost:7654/auth/result')
    end
  end

  context 'saml sp requests ialmax' do
    it 'returns ial1 info for a non-verified user' do
      user = create(:user, :signed_up)
      visit_saml_authn_request_url(
        overrides: {
          issuer: sp1_issuer,
          authn_context: [
            Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
            "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
            "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
          ],
        },
      )
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq sign_up_completed_path
      expect(page).to have_content(user.email)

      click_agree_and_continue

      expect(current_url).to eq @saml_authn_request
    end

    it 'returns ial2 info for a verified user' do
      user = create(
        :profile, :active, :verified,
        pii: { first_name: 'John', ssn: '111223333' }
      ).user
      visit_saml_authn_request_url(
        overrides: {
          issuer: sp1_issuer,
          authn_context: [
            Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
            "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
            "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
          ],
        },
      )
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq sign_up_completed_path
      expect(page).to have_content('1**-**-***3')

      click_agree_and_continue

      expect(current_url).to eq @saml_authn_request
    end
  end

  context 'when piv/cac is required' do
    before do
      visit_idp_from_oidc_sp_with_hspd12_and_require_piv_cac
    end

    it 'forces user to add a piv/cac if they do not have one' do
      user = create(:user, :signed_up)
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq two_factor_options_path
      select_2fa_option('piv_cac')

      expect(page).to have_current_path setup_piv_cac_path
    end

    it 'uses the piv cac if they have one' do
      user = create(:user, :with_phone, :with_piv_or_cac)
      fill_in_credentials_and_submit(user.email, user.password)

      expect(current_path).to eq login_two_factor_piv_cac_path
    end
  end

  context 'double clicking on "Agree and Continue"' do
    it 'should not blow up' do
      user = create(:user, :signed_up)
      visit_idp_from_sp_with_ial1(:oidc)
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq sign_up_completed_path
      expect(page).to have_content(user.email)

      agree_and_continue_button = find_button(t('sign_up.agree_and_continue'))
      action_url = agree_and_continue_button.find(:xpath, '..')[:action]
      agree_and_continue_button.click

      expect(current_url).to start_with('http://localhost:7654/auth/result')

      response = page.driver.post(action_url)
      expect(response).to be_redirect
    end
  end

  def perform_steps_to_get_to_add_piv_cac_during_sign_up
    user = create(:user, :signed_up, :with_phone)
    visit_idp_from_sp_with_ial1(:oidc)
    click_on t('account.login.piv_cac')
    allow(FeatureManagement).to receive(:development_and_identity_pki_disabled?).and_return(false)

    stub_piv_cac_service
    nonce = get_piv_cac_nonce_from_link(find_link(t('forms.piv_cac_login.submit')))
    visit_piv_cac_service(
      current_url,
      nonce: nonce,
      dn: 'C=US, O=U.S. Government, OU=DoD, OU=PKI, CN=DOE.JOHN.1234',
      uuid: SecureRandom.uuid,
      subject: 'SomeIgnoredSubject',
    )

    expect(page).to have_current_path(login_piv_cac_error_path(error: 'user.not_found'))
    visit new_user_session_path
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default
    expect(current_path).to eq login_add_piv_cac_prompt_path
    fill_in 'name', with: 'Card 1'
  end
end
