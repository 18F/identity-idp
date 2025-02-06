require 'rails_helper'

RSpec.feature 'Sign in' do
  include SessionTimeoutWarningHelper
  include ActionView::Helpers::DateHelper
  include PersonalKeyHelper
  include SamlAuthHelper
  include OidcAuthHelper
  include SpAuthHelper
  include IdvHelper
  include DocAuthHelper
  include AbTestsHelper

  context 'service provider is on the ialmax allow list' do
    before do
      allow(IdentityConfig.store).to receive(:allowed_ialmax_providers) {
        ['urn:gov:gsa:openidconnect:sp:server']
      }
    end

    scenario 'user signs in as ialmax and does not see ial2 help text' do
      visit_idp_from_oidc_sp_with_ialmax

      expect(page).to_not have_content 'The page you were looking for doesn’t exist'
    end
  end

  scenario 'user cannot sign in if not registered' do
    signin('test@example.com', 'Please123!')
    link_url = new_user_password_url

    expect(page)
      .to have_link t('devise.failure.not_found_in_database_link_text', href: link_url)
  end

  scenario 'user is suspended, gets show please call page after 2fa' do
    user = create(:user, :fully_registered, :suspended)
    service_provider = ServiceProvider.find_by(issuer: OidcAuthHelper::OIDC_IAL1_ISSUER)
    IdentityLinker.new(user, service_provider).link_identity(
      verified_attributes: %w[openid email],
    )

    visit_idp_from_sp_with_ial1(:oidc)
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(page).to have_current_path(user_please_call_path)
  end

  scenario 'user with old terms of use can accept and continue to IAL1 SP' do
    user = create(
      :user,
      :fully_registered,
      :with_piv_or_cac,
      accepted_terms_at: IdentityConfig.store.rules_of_use_updated_at - 1.minute,
    )
    service_provider = ServiceProvider.find_by(issuer: OidcAuthHelper::OIDC_IAL1_ISSUER)
    IdentityLinker.new(user, service_provider).link_identity(
      verified_attributes: %w[openid email],
    )

    visit_idp_from_sp_with_ial1(:oidc)
    click_on t('account.login.piv_cac')
    fill_in_piv_cac_credentials_and_submit(user, user.piv_cac_configurations.first.x509_dn_uuid)

    expect(current_url).to eq rules_of_use_url
    accept_rules_of_use_and_continue_if_displayed
    expect(oidc_redirect_url).to start_with service_provider.redirect_uris.first
  end

  scenario 'user with old terms of use can accept and continue to IAL2 SP' do
    user = create(
      :user,
      :fully_registered,
      :with_piv_or_cac,
      accepted_terms_at: IdentityConfig.store.rules_of_use_updated_at - 1.minute,
    )
    create(
      :profile,
      :active,
      :verified,
      user: user,
      pii: { first_name: 'John', ssn: '111223333' },
    )
    service_provider = ServiceProvider.find_by(issuer: OidcAuthHelper::OIDC_ISSUER)
    IdentityLinker.new(user, service_provider).link_identity(
      verified_attributes: %w[email given_name family_name social_security_number address phone],
      ial: 2,
    )

    visit_idp_from_sp_with_ial2(:oidc)
    click_on t('account.login.piv_cac')
    fill_in_piv_cac_credentials_and_submit(user, user.piv_cac_configurations.first.x509_dn_uuid)

    expect(current_url).to eq capture_password_url

    fill_in 'Password', with: user.password
    click_submit_default

    expect(current_url).to eq rules_of_use_url
    accept_rules_of_use_and_continue_if_displayed
    expect(oidc_redirect_url).to start_with service_provider.redirect_uris.first
  end

  scenario 'user attempts sign in with piv/cac with no account then creates account' do
    visit_idp_from_sp_with_ial1(:oidc)
    click_on t('account.login.piv_cac')
    allow(FeatureManagement).to receive(:development_and_identity_pki_disabled?).and_return(false)

    stub_piv_cac_service
    click_on t('forms.piv_cac_login.submit')
    follow_piv_cac_redirect

    expect(page).to have_current_path(login_piv_cac_error_path(error: 'user.not_found'))
    visit sign_up_email_path
    email = 'foo@bar.com'
    submit_form_with_valid_email(email)
    click_confirmation_link_in_email(email)
    submit_form_with_valid_password
    expect(page).to have_current_path(authentication_methods_setup_path)
    select_2fa_option('phone')
    fill_in :new_phone_form_phone, with: '2025551314'
    click_send_one_time_code
    fill_in_code_with_last_phone_otp
    click_submit_default
    skip_second_mfa_prompt
    click_agree_and_continue
    expect(oidc_redirect_url).to start_with('http://localhost:7654/auth/result')
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

  scenario 'user can see and use password visibility toggle', js: true do
    visit new_user_session_path

    check t('components.password_toggle.toggle_label')
    expect(page).to have_css('input.password[type="text"]')
  end

  scenario 'user session expires in amount of time specified by Devise config' do
    sign_in_and_2fa_user

    visit account_path
    expect(page).to have_current_path account_path

    travel(Devise.timeout_in + 1.minute)

    visit account_path
    expect(page).to have_current_path root_path

    travel_back
  end

  scenario 'user session cookie has no explicit expiration time (dies with browser exit)' do
    sign_in_and_2fa_user

    expect(session_cookie.expires).to be_nil
  end

  context 'session approaches timeout', js: true do
    around do |example|
      with_forgery_protection { example.run }
    end

    before :each do
      allow(IdentityConfig.store).to receive(:session_check_frequency).and_return(1)
      allow(IdentityConfig.store).to receive(:session_check_delay).and_return(0)
      allow(IdentityConfig.store).to receive(:session_timeout_warning_seconds)
        .and_return(Devise.timeout_in)

      sign_in_and_2fa_user
      visit forget_all_browsers_path
      expect(page).to have_css('.usa-js-modal--active', wait: 5)
    end

    scenario 'user sees warning before session times out' do
      minutes_and = [
        t('datetime.dotiw.minutes', count: IdentityConfig.store.session_timeout_in_minutes - 1),
        t('datetime.dotiw.two_words_connector'),
      ].join('')

      pattern1 = Regexp.new(minutes_and + t('datetime.dotiw.seconds.other', count: '\d+'))
      expect(page).to have_content(pattern1, wait: 5)
      time = page.text[pattern1]
      seconds = time.split(t('datetime.dotiw.two_words_connector')).last[/\d+/].to_i
      pattern2 = Regexp.new(
        minutes_and + t(
          'datetime.dotiw.seconds.other',
          count: (seconds - 10...seconds).to_a.join('|'),
        ),
      )
      expect(page).to have_content(pattern2, wait: 5)
    end

    scenario 'user can continue browsing with refreshed CSRF token' do
      token = first('[name=authenticity_token]', visible: false).value
      click_button t('notices.timeout_warning.signed_in.continue')
      expect(page).not_to have_css('.usa-js-modal--active')
      expect(page).to have_css(
        "[name=authenticity_token]:not([value='#{token}'])",
        visible: false,
        wait: 5,
      )
    end

    scenario 'user has option to sign out' do
      click_button(t('notices.timeout_warning.signed_in.sign_out'))

      expect(page).to have_content t('devise.sessions.signed_out')
      expect(page).to have_current_path new_user_session_path
    end
  end

  context 'user only signs in via email and password', js: true do
    it 'displays the session timeout warning with partially signed in copy' do
      allow(IdentityConfig.store).to receive(:session_check_frequency).and_return(1)
      allow(IdentityConfig.store).to receive(:session_check_delay).and_return(0)
      allow(IdentityConfig.store).to receive(:session_timeout_warning_seconds)
        .and_return(Devise.timeout_in)
      allow(Devise).to receive(:timeout_in)
        .and_return(IdentityConfig.store.session_timeout_warning_seconds + 1)

      user = create(:user, :fully_registered)
      sign_in_user(user)
      visit user_two_factor_authentication_path

      expect(page).to have_css('.usa-js-modal--active', wait: 5)
      expect(page).to have_content(t('notices.timeout_warning.partially_signed_in.continue'))
      expect(page).to have_content(t('notices.timeout_warning.partially_signed_in.sign_out'))
    end
  end

  context 'signing back in after session timeout length' do
    around do |example|
      with_forgery_protection { example.run }
    end

    it 'fails to sign in the user, with CSRF error' do
      user = sign_in_and_2fa_user
      click_button(t('links.sign_out'), match: :first)

      travel(Devise.timeout_in + 1.minute) do
        expect(page).to_not have_content(t('forms.buttons.continue'))

        # Redis doesn't respect ActiveSupport::Testing::TimeHelpers, so expire session manually.
        session_store.send(
          :delete_session,
          nil,
          Rack::Session::SessionId.new(session_cookie.value),
          drop: true,
        )

        fill_in_credentials_and_submit(user.email, user.password)
        expect(page).to have_content t('errors.general')

        fill_in_credentials_and_submit(user.email, user.password)
        expect(page).to have_current_path login_two_factor_path(otp_delivery_preference: 'sms')
      end
    end

    context 'create account' do
      it 'shows the timeout modal when the session expiration approaches', js: true do
        allow(Devise).to receive(:timeout_in)
          .and_return(IdentityConfig.store.session_timeout_warning_seconds + 1)

        visit sign_up_email_path
        fill_in t('forms.registration.labels.email'), with: 'test@example.com'

        expect(page).to have_css('.usa-js-modal--active', wait: 10)

        click_button t('notices.timeout_warning.partially_signed_in.continue')

        expect(page).not_to have_css('.usa-js-modal--active')
        expect(find_field(t('forms.registration.labels.email')).value).not_to be_blank
      end
    end

    context 'sign in' do
      it 'shows the timeout modal when the session expiration approaches', js: true do
        allow(Devise).to receive(:timeout_in)
          .and_return(IdentityConfig.store.session_timeout_warning_seconds + 1)

        visit root_path
        fill_in t('account.index.email'), with: 'test@example.com'

        expect(page).to have_css('.usa-js-modal--active', wait: 10)

        click_button t('notices.timeout_warning.partially_signed_in.continue')
        expect(find_field(t('account.index.email')).value).not_to be_blank
      end

      it 'reloads the sign in page when cancel is clicked', js: true do
        allow(Devise).to receive(:timeout_in)
          .and_return(IdentityConfig.store.session_timeout_warning_seconds + 1)

        visit root_path
        fill_in t('account.index.email'), with: 'test@example.com'

        expect(page).to have_css('.usa-js-modal--active', wait: 10)

        click_button t('notices.timeout_warning.partially_signed_in.sign_out')
        expect(find_field(t('account.index.email')).value).to be_blank
      end
    end
  end

  context 'user attempts too many concurrent sessions' do
    context 'with email and password' do
      scenario 'redirects to home page with error' do
        analytics = FakeAnalytics.new
        allow(Analytics).to receive(:new).and_return(analytics)

        user = user_with_2fa

        perform_in_browser(:one) do
          sign_in_live_with_2fa(user)

          expect(page).to have_current_path account_path
        end

        perform_in_browser(:two) do
          sign_in_live_with_2fa(user)

          expect(page).to have_current_path account_path
        end

        perform_in_browser(:one) do
          visit account_path

          expect(page).to have_current_path new_user_session_path
          expect(page).to have_content(t('devise.failure.session_limited'))

          expect(analytics.events[:concurrent_session_logout].count).to eq 1
        end
      end
    end

    context 'with piv/cac' do
      scenario 'redirects to home page with error' do
        user = user_with_piv_cac

        perform_in_browser(:one) do
          sign_in_user_with_piv(user)

          expect(page).to have_current_path account_path
        end

        perform_in_browser(:two) do
          sign_in_user_with_piv(user)

          expect(page).to have_current_path account_path
        end

        perform_in_browser(:one) do
          visit account_path

          expect(page).to have_current_path new_user_session_path
          expect(page).to have_content(t('devise.failure.session_limited'))
        end
      end
    end

    context 'with sp' do
      scenario 'redirects to home page with error  and preserves branded experience' do
        user = user_with_2fa
        service_provider = ServiceProvider.find_by(issuer: OidcAuthHelper::OIDC_IAL1_ISSUER)
        IdentityLinker.new(user, service_provider).link_identity(
          verified_attributes: %w[openid email],
        )

        perform_in_browser(:one) do
          visit_idp_from_sp_with_ial1(:oidc)
          sign_in_live_with_2fa(user)
        end

        perform_in_browser(:two) do
          visit_idp_from_sp_with_ial1(:oidc)
          sign_in_live_with_2fa(user)
        end

        perform_in_browser(:one) do
          visit account_path

          expect(page).to have_current_path new_user_session_path
          expect(page).to have_content(t('devise.failure.session_limited'))
          expect_branded_experience
        end
      end
    end
  end

  context 'attribute_encryption_key is changed but queue does not contain any previous keys' do
    context 'when logging in with email and password' do
      it 'throws an exception and does not overwrite User email' do
        email = 'test@example.com'
        password = 'salty pickles'

        create(:user, :fully_registered, email: email, password: password)

        user = User.find_with_email(email)
        encrypted_email = user.last_sign_in_email_address.encrypted_email

        rotate_attribute_encryption_key_with_invalid_queue

        expect { signin(email, password) }
          .to raise_error Encryption::EncryptionError, 'unable to decrypt attribute with any key'

        user = user.reload
        expect(user.last_sign_in_email_address.encrypted_email).to eq encrypted_email
      end
    end

    context 'when logging in with piv/cac' do
      it 'does not overwrite User email' do
        email = 'test@example.com'
        password = 'salty pickles'

        create(:user, :fully_registered, email: email, password: password)

        user = User.find_with_email(email)
        encrypted_email = user.last_sign_in_email_address.encrypted_email

        rotate_attribute_encryption_key_with_invalid_queue

        sign_in_user_with_piv(user)

        user = user.reload
        expect(user.last_sign_in_email_address.encrypted_email).to eq encrypted_email
      end
    end
  end

  context 'KMS is on and user enters incorrect password' do
    it 'redirects to root_path with user-friendly error message, not a 500 error' do
      user = create(:user)
      email = user.email
      allow(FeatureManagement).to receive(:use_kms?).and_return(true)
      stub_aws_kms_client_invalid_ciphertext

      signin(email, 'invalid')

      link_url = new_user_password_url

      expect(page)
        .to have_link t('devise.failure.invalid_link_text', href: link_url)
      expect(page).to have_current_path root_path
    end
  end

  context 'invalid request_id' do
    it 'allows the user to sign in and does not try to redirect to any SP' do
      user = create(:user, :fully_registered)

      visit new_user_session_path(request_id: 'invalid')
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      expect(page).to have_current_path account_path
    end

    context 'with email and password' do
      it 'allows the user to sign in and does not try to redirect to any SP' do
        allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
        user = create(:user, :fully_registered)

        visit new_user_session_path(request_id: 'invalid')
        fill_in_credentials_and_submit(user.email, user.password)
        click_submit_default

        expect(page).to have_current_path account_path
      end
    end

    context 'with piv/cac' do
      it 'allows the user to sign in and does not try to redirect to any SP' do
        user = create(:user, :fully_registered, :with_piv_or_cac)

        visit new_user_session_path(request_id: 'invalid')
        signin_with_piv(user)

        expect(page).to have_current_path account_path
      end
    end
  end

  context 'CSRF error' do
    it 'redirects to sign in page with flash message' do
      user = create(:user, :fully_registered)
      visit new_user_session_path(request_id: '123')
      allow_any_instance_of(Users::SessionsController)
        .to receive(:create).and_raise(ActionController::InvalidAuthenticityToken)

      fill_in_credentials_and_submit(user.email, user.password)

      expect(current_url).to eq new_user_session_url(request_id: '123')
      expect(page).to have_content t('errors.general')
    end
  end

  it_behaves_like 'signing in with the site in Spanish', :saml
  it_behaves_like 'signing in with the site in Spanish', :oidc

  context 'user signs in with Voice OTP delivery preference to an unsupported country' do
    it 'falls back to SMS with an error message if SMS is supported' do
      user = create(
        :user, :fully_registered,
        otp_delivery_preference: 'voice', with: { phone: '+61 02 1234 5678' }
      )
      signin(user.email, user.password)

      expect(Telephony::Test::Call.calls.length).to eq(0)
      expect(Telephony::Test::Message.messages.length).to eq(1)
      expect(page)
        .to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms'))
      expect(page).to have_content t(
        'two_factor_authentication.otp_delivery_preference.voice_unsupported',
        location: 'Australia',
      )
      expect(user.reload.otp_delivery_preference).to eq 'sms'
    end

    it 'shows error message if SMS and Voice are not supported' do
      user = create(
        :user, :fully_registered,
        otp_delivery_preference: 'voice', with: { phone: '+213 09 1234 5678' }
      )
      signin(user.email, user.password)

      expect(Telephony::Test::Call.calls.length).to eq(0)
      expect(Telephony::Test::Message.messages.length).to eq(0)
      expect(page)
        .to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms'))
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
        :user, :fully_registered,
        otp_delivery_preference: 'sms', with: { phone: unsupported_country_phone_number }
      )
      signin(user.email, user.password)
      visit login_two_factor_path(otp_delivery_preference: 'voice')

      expect(Telephony::Test::Call.calls.length).to eq(0)
      expect(Telephony::Test::Message.messages.length).to eq(1)
      expect(page)
        .to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms'))
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
        :user, :fully_registered,
        otp_delivery_preference: 'sms', with: { phone: unsupported_country_phone_number }
      )
      signin(user.email, user.password)
      visit otp_send_path(
        otp_delivery_selection_form: { otp_delivery_preference: 'voice', resend: true },
      )

      expect(Telephony::Test::Call.calls.length).to eq(0)
      expect(Telephony::Test::Message.messages.length).to eq(1)
      expect(page)
        .to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms'))
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
        :user, :fully_registered,
        otp_delivery_preference: 'voice', with: { phone: unsupported_country_phone_number }
      )
      signin(user.email, user.password)
      visit otp_send_path(
        otp_delivery_selection_form: { otp_delivery_preference: 'voice', resend: true },
      )

      expect(Telephony::Test::Call.calls.length).to eq(0)
      expect(Telephony::Test::Message.messages.length).to eq(1)
      expect(page)
        .to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms'))
      expect(page).to have_content t(
        'two_factor_authentication.otp_delivery_preference.voice_unsupported',
        location: unsupported_country_name,
      )
      expect(user.reload.otp_delivery_preference).to eq 'sms'
    end
  end

  it_behaves_like 'signing in from service provider', :saml
  it_behaves_like 'signing in from service provider', :oidc
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
  it_behaves_like 'signing in as proofed account with broken personal key', :oidc, sp_ial: 2

  context 'user signs in and chooses another authentication method' do
    it 'signs out the user if they choose to cancel' do
      user = create(:user, :fully_registered)
      signin(user.email, user.password)
      accept_rules_of_use_and_continue_if_displayed
      click_link t('two_factor_authentication.login_options_link_text')
      click_on t('links.cancel')

      expect(page).to have_current_path root_path
      expect(page).to have_content(t('devise.sessions.signed_out'))
    end
  end

  context 'user signs in when accepted_terms_at is out of date', js: true do
    it 'validates terms checkbox and signs in successfully' do
      user = create(:user, :fully_registered, accepted_terms_at: nil)
      signin(user.email, user.password)

      click_button t('forms.buttons.continue')
      expect(page).to have_css(':focus[name="rules_of_use_form[terms_accepted]"]', visible: :all)

      check 'rules_of_use_form[terms_accepted]'

      click_button t('forms.buttons.continue')
      expect(page).to have_current_path login_two_factor_path(otp_delivery_preference: 'sms')
    end
  end

  context 'user signs in with personal key, visits account page' do
    # this can happen if you submit the personal key form multiple times quickly
    it 'does not redirect to the personal key page' do
      user = create(:user, :fully_registered)
      old_personal_key = PersonalKeyGenerator.new(user).generate!
      signin(user.email, user.password)
      choose_another_security_option('personal_key')
      enter_personal_key(personal_key: old_personal_key)
      click_submit_default
      visit account_path
      expect(page).to have_current_path(account_path)
    end
  end

  context 'visiting via SP1, then via SP2, then signing in' do
    it 'redirects to SP2' do
      user = create(:user, :fully_registered)
      visit_idp_from_sp_with_ial1(:saml)
      visit_idp_from_sp_with_ial1(:oidc)
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_agree_and_continue

      redirect_uri = URI(oidc_redirect_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end

  context 'a prompt login sp redirects back to auth url immediately after we redirect to them' do
    it 'logs an SP bounce and displays the bounced error screen' do
      user = create(:user, :fully_registered)
      visit_idp_from_oidc_sp_with_loa1_prompt_login
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_agree_and_continue

      visit_idp_from_oidc_sp_with_loa1_prompt_login
      expect(page).to have_current_path(bounced_path)
    end
  end

  context 'multiple piv cacs' do
    it 'allows you to sign in with either' do
      user = create(:user, :fully_registered, :with_piv_or_cac)
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

  context 'oidc sp requests ialmax' do
    context 'the service_provider is on the allow list' do
      before do
        allow(IdentityConfig.store).to receive(:allowed_ialmax_providers) {
                                         ['urn:gov:gsa:openidconnect:sp:server']
                                       }
      end

      it 'returns ial1 info for a non-verified user' do
        user = create(:user, :fully_registered)
        visit_idp_from_oidc_sp_with_ialmax
        fill_in_credentials_and_submit(user.email, user.password)
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(page).to have_current_path sign_up_completed_path
        expect(page).to have_content(user.email)

        click_agree_and_continue

        expect(oidc_redirect_url).to start_with('http://localhost:7654/auth/result')
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

        expect(page).to have_current_path sign_up_completed_path
        expect(page).to have_content('1**-**-***3')

        click_agree_and_continue

        expect(oidc_redirect_url).to start_with('http://localhost:7654/auth/result')
      end
    end

    context 'the service provider is not on the allow list' do
      it 'returns an error' do
        create(:user, :fully_registered)
        visit_idp_from_oidc_sp_with_ialmax

        expect(oidc_redirect_url).to include('error=invalid_request')
      end
    end
  end

  context 'saml sp requests ialmax' do
    context 'the service provider is on the allow list' do
      before do
        allow(IdentityConfig.store).to receive(:allowed_ialmax_providers) { [sp1_issuer] }
      end

      it 'returns ial1 info for a non-verified user' do
        user = create(:user, :fully_registered)
        visit_saml_authn_request_url(
          overrides: {
            issuer: sp1_issuer,
            authn_context: [
              Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
              Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF +
               'first_name:last_name email, ssn',
              "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
            ],
          },
        )
        fill_in_credentials_and_submit(user.email, user.password)
        fill_in_code_with_last_phone_otp
        click_submit_default_twice

        expect(page).to have_current_path sign_up_completed_path
        expect(page).to have_content(user.email)

        click_agree_and_continue

        expect(current_url).to eq complete_saml_url
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
              Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF +
              'first_name:last_name email, ssn',
              "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
            ],
          },
        )
        fill_in_credentials_and_submit(user.email, user.password)
        fill_in_code_with_last_phone_otp
        click_submit_default
        click_submit_default

        expect(page).to have_current_path sign_up_completed_path
        expect(page).to have_content('1**-**-***3')

        click_agree_and_continue

        expect(current_url).to eq complete_saml_url
      end
    end

    context 'the service provider is not on the allow list' do
      it 'redirects to an error page for ial1 user' do
        create(:user, :fully_registered)
        visit_saml_authn_request_url(
          overrides: {
            issuer: sp1_issuer,
            authn_context: [
              Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
              Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF +
              'first_name:last_name email, ssn',
              "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
            ],
          },
        )
        expect(page).to_not have_content 'The page you were looking for doesn’t exist'
      end

      it 'redirects to an error page for ial2 user' do
        create(
          :profile, :active, :verified,
          pii: { first_name: 'John', ssn: '111223333' }
        ).user
        visit_saml_authn_request_url(
          overrides: {
            issuer: sp1_issuer,
            authn_context: [
              Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
              Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF +
                'first_name:last_name email, ssn',
              "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
            ],
          },
        )
        expect(page).to_not have_content 'The page you were looking for doesn’t exist'
      end
    end
  end

  context 'when the reCAPTCHA check fails' do
    let(:user) { create(:user, :fully_registered) }

    before do
      allow(FeatureManagement).to receive(:sign_in_recaptcha_enabled?).and_return(true)
      allow(IdentityConfig.store).to receive(:recaptcha_mock_validator).and_return(true)
      allow(IdentityConfig.store).to receive(:sign_in_recaptcha_log_failures_only)
        .and_return(sign_in_recaptcha_log_failures_only)
      allow(IdentityConfig.store).to receive(:sign_in_recaptcha_score_threshold).and_return(0.2)
      allow(IdentityConfig.store).to receive(:sign_in_recaptcha_percent_tested).and_return(100)
      reload_ab_tests
    end

    after do
      reload_ab_tests
    end

    context 'when configured to log failures only' do
      let(:sign_in_recaptcha_log_failures_only) { true }
      it_behaves_like 'logs reCAPTCHA event and redirects appropriately',
                      successful_sign_in: true
    end

    context 'when not configured to log failures only' do
      let(:sign_in_recaptcha_log_failures_only) { false }
      it_behaves_like 'logs reCAPTCHA event and redirects appropriately',
                      successful_sign_in: false
    end
  end

  context 'check_password_compromised feature toggle is true' do
    before do
      allow(FeatureManagement).to receive(:check_password_enabled?).and_return(true)
    end

    context 'user has a compromised password' do
      let(:user) { create(:user, :fully_registered, password: '3.141592653589793238') }
      context 'user is chosen to check if password compromised' do
        before do
          allow(SecureRandom).to receive(:random_number).and_return(5)
          allow(IdentityConfig.store).to receive(:compromised_password_randomizer_threshold)
            .and_return(2)
        end
        it 'should bring user to manage password page with warning' do
          visit_idp_from_sp_with_ial1(:oidc)
          fill_in_credentials_and_submit(user.email, user.password)
          fill_in_code_with_last_phone_otp
          click_submit_default

          expect(page).to have_current_path manage_password_path
        end

        it 'should redirect user to after_sign_in_path after editing password' do
          visit_idp_from_sp_with_ial1(:oidc)
          fill_in_credentials_and_submit(user.email, user.password)
          fill_in_code_with_last_phone_otp
          click_submit_default

          expect(page).to have_current_path manage_password_path

          password = 'salty pickles'
          fill_in t('forms.passwords.edit.labels.password'), with: password
          fill_in t('components.password_confirmation.confirm_label'), with: password
          click_button t('forms.passwords.edit.buttons.submit')

          click_agree_and_continue

          expect(oidc_redirect_url).to start_with('http://localhost:7654/auth/result')
        end
      end

      context 'user is not chosen to check if password compromised' do
        before do
          allow(SecureRandom).to receive(:random_number).and_return(2)
          allow(IdentityConfig.store).to receive(:compromised_password_randomizer_threshold)
            .and_return(5)
        end
        it 'should continue without issue' do
          visit new_user_session_path
          fill_in_credentials_and_submit(user.email, user.password)
          fill_in_code_with_last_phone_otp
          click_submit_default

          expect(page).to have_current_path account_path
        end
      end
    end

    context 'user does not have compromised password' do
      let(:user) { create(:user, :fully_registered) }
      context 'user is chosen to check if password compromised' do
        before do
          allow(SecureRandom).to receive(:random_number).and_return(5)
          allow(IdentityConfig.store).to receive(:compromised_password_randomizer_threshold)
            .and_return(2)
        end
        it 'should bring user to account page and set password compromised attr' do
          visit new_user_session_path
          fill_in_credentials_and_submit(user.email, user.password)
          fill_in_code_with_last_phone_otp
          click_submit_default

          expect(page).to have_current_path account_path
          user.reload
          expect(user.password_compromised_checked_at).to be_truthy
        end
      end

      context 'user is not chosen to check if password compromised' do
        before do
          allow(SecureRandom).to receive(:random_number).and_return(2)
          allow(IdentityConfig.store).to receive(:compromised_password_randomizer_threshold)
            .and_return(5)
        end
        it 'should continue without issue and does not set password compromised attr' do
          visit new_user_session_path
          fill_in_credentials_and_submit(user.email, user.password)
          fill_in_code_with_last_phone_otp
          click_submit_default

          expect(page).to have_current_path account_path
          user.reload
          expect(user.password_compromised_checked_at).to be_falsey
        end
      end
    end
  end

  context 'when piv/cac is required' do
    before do
      visit_idp_from_oidc_sp_with_hspd12_and_require_piv_cac
    end

    it 'forces user to add a piv/cac if they do not have one' do
      user = create(:user, :fully_registered)
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path authentication_methods_setup_path
      select_2fa_option('piv_cac')

      expect(page).to have_current_path setup_piv_cac_path
    end

    it 'uses the piv cac if they have one' do
      user = create(:user, :with_phone, :with_piv_or_cac)
      fill_in_credentials_and_submit(user.email, user.password)

      expect(page).to have_current_path login_two_factor_piv_cac_path
    end
  end

  context 'double clicking on "Agree and Continue"' do
    it 'should not blow up' do
      user = create(:user, :fully_registered)
      visit_idp_from_sp_with_ial1(:oidc)
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path sign_up_completed_path
      expect(page).to have_content(user.email)

      agree_and_continue_button = find_button(t('sign_up.agree_and_continue'))
      action_url = agree_and_continue_button.ancestor('form')[:action]
      agree_and_continue_button.click

      expect(oidc_redirect_url).to start_with('http://localhost:7654/auth/result')

      response = page.driver.post(action_url)
      expect(response).to be_redirect
    end
  end

  def with_forgery_protection
    original_allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
    ActionController::Base.allow_forgery_protection = original_allow_forgery_protection
  end
end
