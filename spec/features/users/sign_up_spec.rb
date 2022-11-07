require 'rails_helper'

feature 'Sign Up' do
  include SamlAuthHelper
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

    sign_up_and_set_password

    freeze_time do
      (IdentityConfig.store.phone_confirmation_max_attempts + 1).times do
        visit phone_setup_path
        fill_in 'new_phone_form_phone', with: '2025551313'
        click_send_one_time_code
      end

      timeout = distance_of_time_in_words(
        Throttle.attempt_window_in_minutes(:phone_confirmation).minutes,
      )

      expect(current_path).to eq(authentication_methods_setup_path)
      expect(page).to have_content(
        I18n.t(
          'errors.messages.phone_confirmation_throttled',
          timeout: timeout,
        ),
      )
    end
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
      copied_text = page.evaluate_async_script('navigator.clipboard.readText().then(arguments[0])')
      expect(did_validate_name.call).to_not eq true

      otp_input = page.find('.one-time-code-input')
      otp_input.set(generate_totp_code(copied_text))
      click_button 'Submit'
      expect(did_validate_name.call).to eq true

      fill_in 'name', with: 'Authentication app'
      click_button 'Submit'
      expect(page).to have_current_path account_path
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

    expect(page).to have_current_path account_path
  end

  it 'does not allow PIV/CAC during setup on mobile' do
    allow(BrowserCache).to receive(:parse).and_return(mobile_device)

    sign_in_user

    expect(page).to have_selector('#two_factor_options_form_selection_phone', count: 1)
    expect(page).to have_selector('#two_factor_options_form_selection_piv_cac', count: 0)
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
    visit authentication_methods_setup_path
    click_on 'Continue'

    expect(page).to have_content(t('errors.two_factor_auth_setup.must_select_option'))
  end

  it 'does not show the remember device option as the default when the SP is AAL2' do
    ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:server').update!(
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

    expect(page).to_not have_selector('#two_factor_options_form_selection_phone', count: 1)
    expect(page).to_not have_selector('#two_factor_options_form_selection_webauthn', count: 1)
    expect(page).to_not have_selector('#two_factor_options_form_selection_auth_app', count: 1)
    expect(page).to_not have_selector('#two_factor_options_form_selection_backup_code', count: 1)
    expect(page).to have_selector('#two_factor_options_form_selection_piv_cac', count: 1)

    select_2fa_option('piv_cac')
    expect(page).to_not have_content(t('two_factor_authentication.piv_cac_fallback.question'))
  end
end
