require 'rails_helper'

RSpec.feature 'Sign Up', allowed_extra_analytics: [:*] do
  include SamlAuthHelper
  include OidcAuthHelper
  include DocAuthHelper
  include ActionView::Helpers::DateHelper

  context 'confirmation token error message does not persist on success' do
    scenario 'with blank token' do
      visit sign_up_create_email_confirmation_url(confirmation_token: '')
      expect(page).to have_content t('errors.messages.confirmation_invalid_token')

      sign_up

      expect(page).not_to have_content t('errors.messages.confirmation_invalid_token')
    end

    scenario 'with invalid token' do
      visit sign_up_create_email_confirmation_url(confirmation_token: 'foo')
      expect(page).to have_content t('errors.messages.confirmation_invalid_token')

      sign_up

      expect(page).not_to have_content t('errors.messages.confirmation_invalid_token')
    end

    scenario 'with no token and an email address that contains a nil token' do
      EmailAddress.create(user_id: 1, email: 'foo@bar.gov')
      visit sign_up_create_email_confirmation_url
      expect(page).to have_content t('errors.messages.confirmation_invalid_token')

      sign_up

      expect(page).not_to have_content t('errors.messages.confirmation_invalid_token')
    end
  end

  context 'picking a preferred email language on signup' do
    let(:email) { Faker::Internet.safe_email }

    it 'allows a user to pick a language when entering email' do
      visit sign_up_email_path
      check t('sign_up.terms', app_name: APP_NAME)
      fill_in t('forms.registration.labels.email'), with: email
      choose 'Español'
      click_button t('forms.buttons.submit.default')

      user = User.find_with_email(email)
      expect(user.email_language).to eq('es')
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
  end

  context 'user cancels on MFA screen', email: true do
    before(:each) do
      confirm_email('test@test.com')
      submit_form_with_valid_password
      click_on t('links.cancel_account_creation')
    end

    it 'sends them to the cancel page' do
      expect(current_path).to eq sign_up_cancel_path
    end
  end

  context 'user cancels with language preference set' do
    it 'redirects user to the translated home page' do
      visit sign_up_email_path(locale: 'es')
      click_on t('links.cancel')
      expect(current_path).to eq '/es'
    end
  end

  context 'User in account creation logs in_account_creation_flow for proper analytic events' do
    let(:fake_analytics) { FakeAnalytics.new }
    before do
      allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    end
    it 'logs analytic events for MFA selected with in account creation flow' do
      sign_up_and_set_password
      click_2fa_option('phone')
      click_2fa_option('backup_code')

      click_continue
      fill_in 'new_phone_form_phone', with: '703-555-1212'
      click_send_one_time_code

      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq backup_code_setup_path

      expect(page).to have_link(t('components.download_button.label'))

      click_continue

      expect(page).to have_content(t('notices.backup_codes_configured'))

      expect(fake_analytics).to have_logged_event(
        'Multi-Factor Authentication Setup',
        success: true,
        errors: nil,
        multi_factor_auth_method: 'backup_codes',
        in_account_creation_flow: true,
        enabled_mfa_methods_count: 2,
      )
    end
  end

  scenario 'renders an error when the telephony gem responds with an error' do
    allow(Telephony).to receive(:phone_info).and_return(
      Telephony::PhoneNumberInfo.new(carrier: 'Test', type: :test, error: nil),
    )

    sign_up_and_set_password
    select_2fa_option('phone')
    expect(page).to_not have_content t('two_factor_authentication.otp_make_default_number.title')

    fill_in 'new_phone_form_phone', with: '225-555-1000'
    click_send_one_time_code

    expect(current_path).to eq(phone_setup_path)
    expect(page).to have_content(I18n.t('telephony.error.friendly_message.generic'))
  end

  scenario 'rate limits sign-up phone confirmation attempts' do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(999)
    allow(IdentityConfig.store).to receive(:phone_confirmation_max_attempts).and_return(1)

    sign_up_and_set_password

    (IdentityConfig.store.phone_confirmation_max_attempts + 1).times do
      visit phone_setup_path
      fill_in 'new_phone_form_phone', with: '2025551313'
      click_send_one_time_code
    end

    # whether it says '9 minutes' or '10 minutes' depends on how
    # slowly the test runs.
    rate_limited_message = I18n.t(
      'errors.messages.phone_confirmation_limited',
      timeout: '(10|9) minutes',
    )

    expect(current_path).to eq(authentication_methods_setup_path)

    expect(page).to have_content(/#{rate_limited_message}/)
  end

  scenario 'signing up using phone with a reCAPTCHA challenge', :js do
    allow(IdentityConfig.store).to receive(:phone_recaptcha_mock_validator).and_return(true)
    allow(IdentityConfig.store).to receive(:phone_recaptcha_score_threshold).and_return(0.6)

    sign_up_and_set_password
    select_2fa_option('phone')

    fill_in t('two_factor_authentication.phone_label'), with: '+61 0491 570 006'
    fill_in t('components.captcha_submit_button.mock_score_label'), with: '0.5'
    click_send_one_time_code
    expect(page).to have_content(t('titles.spam_protection'), wait: 5)
    expect(page).to have_link(t('two_factor_authentication.login_options_link_text'))
    expect(page).not_to have_link(t('links.cancel'))
  end

  context 'with js', js: true do
    before do
      page.driver.browser.execute_cdp(
        'Browser.grantPermissions',
        origin: page.server_url,
        permissions: ['clipboardReadWrite', 'clipboardSanitizedWrite'],
      )
    end

    after do
      page.driver.browser.execute_cdp('Browser.resetPermissions')
    end

    def clipboard_text
      # `evaluate_async_script` is expected to be asynchronous, but internally it sets the browser
      # script timeout based on Capybara's configured default wait time. Allow for delay in this
      # asynchronous result while avoiding modifying the default otherwise.
      #
      # See: https://github.com/teamcapybara/capybara/blob/3.38.0/lib/capybara/selenium/driver.rb#L146
      Capybara.using_wait_time(5) do
        page.evaluate_async_script('navigator.clipboard.readText().then(arguments[0])')
      end
    end

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

    it 'allows a user to choose TOTP as 2FA method during sign up' do
      sign_in_user
      select_2fa_option('auth_app')

      name = page.find_field('name')
      name.execute_script('this.addEventListener("invalid", () => this.didValidate = true);')
      did_validate_name = -> { name.evaluate_script('this.didValidate') }

      click_on t('components.clipboard_button.label')
      expect(did_validate_name.call).to_not eq true

      otp_input = page.find('.one-time-code-input__input')
      otp_input.set(generate_totp_code(clipboard_text))
      click_button 'Submit'
      expect(did_validate_name.call).to eq true

      fill_in 'name', with: 'Authentication app'
      click_button 'Submit'
      skip_second_mfa_prompt

      expect(page).to have_current_path account_path
    end

    it 'allows a user to sign up with backup codes and add methods without reauthentication' do
      sign_in_user
      select_2fa_option('backup_code')

      visit phone_setup_path
      expect(page).to have_current_path phone_setup_path
    end
  end

  context 'user accesses password screen with already confirmed token', email: true do
    it 'returns them to the home page' do
      create(:user, :fully_registered, confirmation_token: 'foo')

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
      create(:user, :fully_registered, email: 'userb@test.com', confirmation_token: 'foo')
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
    skip_second_mfa_prompt

    expect(page).to have_current_path account_path
  end

  it 'allows a user to sign up with PIV/CAC and only verifying once when HSPD12 is requested' do
    visit_idp_from_oidc_sp_with_hspd12_and_require_piv_cac
    sign_up_and_set_password
    set_up_2fa_with_piv_cac
    skip_second_mfa_prompt
    click_agree_and_continue

    redirect_uri = URI(oidc_redirect_url)

    expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
  end

  it 'does not allow PIV/CAC during setup on mobile' do
    allow(BrowserCache).to receive(:parse).and_return(mobile_device)

    sign_in_user

    expect(page).to have_selector('#two_factor_options_form_selection_phone', count: 1)
    expect(page).to have_selector('#two_factor_options_form_selection_piv_cac', count: 0)
  end

  it 'does not bypass 2FA when accessing authenticator_setup_path if the user is 2FA enabled' do
    user = create(:user, :fully_registered)
    sign_in_user(user)
    visit authenticator_setup_path

    expect(page).
      to have_current_path login_two_factor_path(otp_delivery_preference: 'sms')
  end

  it 'prompts to sign in when accessing authenticator_setup_path before signing in' do
    create(:user, :fully_registered)
    visit authenticator_setup_path

    expect(page).to have_current_path root_path
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

  context 'legacy (pre multi email) user w/expired confirmation token on user and email_address' do
    it 'does not return an error and redirect to root after confirming and entering password' do
      email = 'test2@test.com'
      User.create!(
        uuid: 'foo', email: email,
      )
      EmailAddress.delete_all
      travel_to(1.year.from_now) do
        visit sign_up_email_path
        submit_form_with_valid_email(email)
        click_confirmation_link_in_email(email)
        submit_form_with_valid_password

        expect(page).to have_current_path(authentication_methods_setup_path)
      end
    end
  end

  context 'user finishes sign up after rules of use change' do
    it 'validates terms checkbox and signs in successfully' do
      user = create(
        :user,
        :unconfirmed,
        accepted_terms_at: IdentityConfig.store.rules_of_use_updated_at - 1.year,
        confirmation_token: 'foo',
      )

      visit sign_up_enter_password_path(confirmation_token: 'foo')
      fill_in t('forms.password'), with: Features::SessionHelper::VALID_PASSWORD
      fill_in(
        t('components.password_confirmation.confirm_label'),
        with: Features::SessionHelper::VALID_PASSWORD,
      )
      click_button t('forms.buttons.continue')

      expect(current_path).to eq rules_of_use_path
      check 'rules_of_use_form[terms_accepted]'

      freeze_time do
        click_button t('forms.buttons.continue')
        expect(current_path).to eq authentication_methods_setup_path
        expect(user.reload.accepted_terms_at).to eq Time.zone.now
      end
    end
  end

  it 'does not regenerate a confirmation token if the token is not expired' do
    email = 'test@test.com'

    visit sign_up_email_path
    submit_form_with_valid_email(email)
    token = User.find_with_email(email).email_addresses.first.confirmation_token

    visit sign_up_email_path
    submit_form_with_valid_email(email)
    expect(token).to eq(User.find_with_email(email).email_addresses.first.confirmation_token)
  end

  it 'redirects back with an error if the user does not select 2FA option' do
    sign_in_user
    click_continue

    expect(page).to have_content(t('errors.two_factor_auth_setup.must_select_option'))

    select_2fa_option('phone')
    expect(page).to have_current_path(phone_setup_path)
    expect(page).not_to have_content(t('errors.two_factor_auth_setup.must_select_option'))
  end

  it 'does not show the remember device option as the default when the SP is AAL2' do
    ServiceProvider.find_by(issuer: OidcAuthHelper::OIDC_IAL1_ISSUER).update!(
      default_aal: 2,
    )
    visit_idp_from_sp_with_ial1(:oidc)
    sign_up_and_set_password
    select_2fa_option('phone')
    fill_in :new_phone_form_phone, with: '2025551313'
    click_send_one_time_code
    expect(page).to_not have_checked_field t('forms.messages.remember_device')
  end

  it 'forces user to setup a PIV/CAC and offers no other option or fallback question' do
    visit_idp_from_oidc_sp_with_hspd12_and_require_piv_cac
    sign_up_and_set_password

    expect(page).to have_field('two_factor_options_form[selection][]', count: 1)
    expect(page).to have_field(t('two_factor_authentication.two_factor_choice_options.piv_cac'))
  end

  it 'allows a user to sign up with backup codes and add methods after without reauthentication' do
    sign_up_and_set_password
    select_2fa_option('backup_code')

    click_button t('forms.buttons.continue')

    expect(page).to have_current_path account_path
    visit phone_setup_path
    expect(page).to have_current_path phone_setup_path
  end

  it 'logs expected analytics events for end-to-end sign-up' do
    analytics = FakeAnalytics.new
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(analytics)

    visit_idp_from_sp_with_ial1(:oidc)
    register_user
    click_agree_and_continue

    expect(analytics).to have_logged_event(
      'SP redirect initiated',
      ial: 1,
      billed_ial: 1,
      sign_in_flow: 'create_account',
    )
  end

  describe 'visiting the homepage by clicking the logo image' do
    context 'on the password confirmation screen' do
      before do
        confirm_email('test@test.com')
      end

      it 'returns them to the homepage' do
        click_link APP_NAME, href: new_user_session_path

        expect(current_path).to eq new_user_session_path
      end
    end

    context 'on the MFA setup screen' do
      before do
        confirm_email('test@test.com')
        submit_form_with_valid_password
      end

      it 'returns them to the MFA setup screen' do
        click_link APP_NAME, href: new_user_session_path

        expect(current_path).to eq authentication_methods_setup_path
      end
    end
  end

  def click_2fa_option(option)
    find("label[for='two_factor_options_form_selection_#{option}']").click
  end
end
