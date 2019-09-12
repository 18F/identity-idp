require 'rails_helper'

feature 'Two Factor Authentication' do
  describe 'When the user has not set up 2FA' do
    scenario 'user is prompted to set up two factor authentication at account creation' do
      user = sign_in_before_2fa

      attempt_to_bypass_2fa_setup

      expect(current_path).to eq two_factor_options_path

      select_2fa_option('phone')

      click_continue

      expect(page).
        to have_content t('titles.phone_setup')

      send_security_code_without_entering_phone_number

      expect(current_path).to eq phone_setup_path

      submit_2fa_setup_form_with_empty_string_phone

      expect(page).to have_content t('errors.messages.missing_field')

      submit_2fa_setup_form_with_invalid_phone

      expect(page).to have_content t('errors.messages.missing_field')

      submit_2fa_setup_form_with_valid_phone

      expect(page).to_not have_content t('errors.messages.improbable_phone')
      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
      expect(MfaContext.new(user).phone_configurations).to be_empty
      expect(user.sms?).to eq true
    end

    context 'with number that does not support voice delivery method' do
      let(:unsupported_phone) { '242-327-0143' }

      scenario 'renders an error if a user submits with JS disabled' do
        sign_in_before_2fa
        select_2fa_option(:phone)
        select_phone_delivery_option(:voice)
        select 'Bahamas', from: 'user_phone_form_international_code'
        fill_in 'user_phone_form_phone', with: unsupported_phone
        click_send_security_code

        expect(current_path).to eq phone_setup_path
        expect(page).to have_content t(
          'two_factor_authentication.otp_delivery_preference.phone_unsupported',
          location: 'Bahamas',
        )

        click_on t('two_factor_authentication.choose_another_option')

        expect(current_path).to eq two_factor_options_path
      end
    end

    context 'with international phone that does not support voice delivery' do
      scenario 'updates international code as user types', :js do
        sign_in_before_2fa
        select_2fa_option(:phone)
        fill_in 'user_phone_form_phone', with: '+81 54 354 3643'

        expect(page.find('#user_phone_form_international_code', visible: false).value).to eq 'JP'

        fill_in 'user_phone_form_phone', with: ''
        fill_in 'user_phone_form_phone', with: '+212 5376'

        expect(page.find('#user_phone_form_international_code', visible: false).value).to eq 'MA'

        fill_in 'user_phone_form_phone', with: ''
        fill_in 'user_phone_form_phone', with: '+81 54354'

        expect(page.find('#user_phone_form_international_code', visible: false).value).to eq 'JP'
      end

      scenario 'allows a user to continue typing even if a number is invalid', :js do
        sign_in_before_2fa
        select_2fa_option(:phone)

        # Because javascript is enabled and we do some fancy pants stuff with radio buttons, we need
        # to click on the radio buttons parent to make a selection
        voice_radio_button = page.find(
          '#user_phone_form_otp_delivery_preference_voice', visible: false
        )
        voice_radio_button.find(:xpath, '..').click

        select_country_and_type_phone_number(country: 'us', number: '12345678901234567890')

        expect(phone_field.value).to eq('12345678901234567890')
      end
    end
  end

  def phone_field
    find('#user_phone_form_phone')
  end

  def select_country_and_type_phone_number(country:, number:)
    find('.selected-flag').click
    find(".country[data-country-code='#{country}']:not(.preferred)").click
    phone_field.send_keys(number)
  end

  def attempt_to_bypass_2fa_setup
    visit account_path
  end

  def send_security_code_without_entering_phone_number
    click_send_security_code
  end

  def submit_2fa_setup_form_with_empty_string_phone
    fill_in 'user_phone_form_phone', with: ''
    click_send_security_code
  end

  def submit_2fa_setup_form_with_invalid_phone
    fill_in 'user_phone_form_phone', with: 'five one zero five five five four three two one'
    click_send_security_code
  end

  def submit_2fa_setup_form_with_valid_phone
    fill_in 'user_phone_form_phone', with: '703-555-1212'
    click_send_security_code
  end

  describe 'When the user has already set up 2FA' do
    it 'automatically sends the OTP to the preferred delivery method' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)

      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
      expect(page).
        to have_content t('two_factor_authentication.header_text')

      attempt_to_bypass_2fa

      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')

      check 'remember_device'
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq account_path
    end

    def attempt_to_bypass_2fa
      visit account_path
    end

    scenario 'user can return to the 2fa options screen' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      click_link t('links.cancel')

      expect(current_path).to eq root_path
    end

    scenario 'user does not have to focus on OTP field', js: true do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)

      expect(page.evaluate_script('document.activeElement.id')).to eq 'code'
    end

    scenario 'the user changes delivery method' do
      user = create(:user, :signed_up, otp_delivery_preference: :sms)
      sign_in_before_2fa(user)

      choose_another_security_option('voice')

      expect(Telephony::Test::Message.messages.length).to eq(1)
      expect(Telephony::Test::Call.calls.length).to eq(1)
    end

    scenario 'the user cannot change delivery method if phone is unsupported' do
      unsupported_phone = '+1 (242) 327-0143'
      user = create(:user, :signed_up, with: { phone: unsupported_phone })
      sign_in_before_2fa(user)

      expect(page).to_not have_link t('links.two_factor_authentication.voice')
    end
  end

  describe 'when the user is PIV/CAC enabled' do
    it 'allows SMS and Voice fallbacks' do
      user = user_with_piv_cac
      sign_in_before_2fa(user)

      expect(current_path).to eq login_two_factor_piv_cac_path

      choose_another_security_option('sms')

      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')

      visit login_two_factor_piv_cac_path

      choose_another_security_option('voice')

      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'voice')
    end

    it 'allows totp fallback when configured' do
      user = create(:user, :signed_up, :with_piv_or_cac, otp_secret_key: 'foo')
      sign_in_before_2fa(user)

      expect(current_path).to eq login_two_factor_piv_cac_path

      choose_another_security_option('auth_app')

      expect(current_path).to eq login_two_factor_authenticator_path
    end

    scenario 'user can cancel PIV/CAC process' do
      user = create(:user, :signed_up, :with_piv_or_cac)
      sign_in_before_2fa(user)

      expect(current_path).to eq login_two_factor_piv_cac_path
      click_link t('links.cancel')

      expect(current_path).to eq root_path
    end

    scenario 'user uses PIV/CAC as their second factor' do
      stub_piv_cac_service

      user = user_with_piv_cac
      sign_in_before_2fa(user)

      nonce = visit_login_two_factor_piv_cac_and_get_nonce

      visit_piv_cac_service(login_two_factor_piv_cac_path,
                            uuid: user.x509_dn_uuid,
                            dn: 'C=US, O=U.S. Government, OU=DoD, OU=PKI, CN=DOE.JOHN.1234',
                            nonce: nonce)
      expect(current_path).to eq account_path
    end

    scenario 'user uses incorrect PIV/CAC as their second factor' do
      stub_piv_cac_service

      user = user_with_piv_cac
      sign_in_before_2fa(user)

      nonce = visit_login_two_factor_piv_cac_and_get_nonce

      visit_piv_cac_service(login_two_factor_piv_cac_path,
                            uuid: user.x509_dn_uuid + 'X',
                            dn: 'C=US, O=U.S. Government, OU=DoD, OU=PKI, CN=DOE.JOHN.12345',
                            nonce: nonce)
      expect(current_path).to eq login_two_factor_piv_cac_path
      expect(page).to have_content(t('two_factor_authentication.invalid_piv_cac'))
    end

    context 'user with Voice preference sends SMS, causing a Twilio error' do
      let(:user) do
        create(:user, :signed_up,
               otp_delivery_preference: 'voice',
               with: { phone: '+17035551212', delivery_preference: 'voice' })
      end
      let(:otp_rate_limiter) { OtpRateLimiter.new(user: user, phone: '+17035551212') }

      it 'does not change their OTP delivery preference' do
        allow(Figaro.env).to receive(:programmable_sms_countries).and_return('CA')

        telephony_error = Telephony::TelephonyError.new('error message')
        allow(Telephony).to receive(:send_authentication_otp).and_raise(telephony_error)
        allow(OtpRateLimiter).to receive(:new).and_return(otp_rate_limiter)
        allow(otp_rate_limiter).to receive(:exceeded_otp_send_limit?).
          and_return(false)

        sign_in_user(user)

        expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'voice')

        choose_another_security_option('sms')

        expect(page).to have_content telephony_error.friendly_message
        expect(user.reload.otp_delivery_preference).to eq 'voice'
      end
    end
  end

  describe 'when the user is not piv/cac enabled' do
    it 'has no link to piv/cac during login' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)

      expect(page).not_to have_link(t('two_factor_authentication.piv_cac_fallback.link'))
    end
  end

  describe 'when the user is TOTP enabled and phone enabled' do
    it 'allows SMS and Voice fallbacks' do
      user = create(:user, :with_authentication_app, :with_phone)
      sign_in_before_2fa(user)

      choose_another_security_option('sms')

      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')

      visit login_two_factor_authenticator_path

      choose_another_security_option('voice')

      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'voice')
    end

    scenario 'user can cancel TOTP process' do
      user = create(:user, :signed_up, otp_secret_key: 'foo')
      sign_in_before_2fa(user)
      click_link t('links.cancel')

      expect(current_path).to eq root_path
    end

    scenario 'attempting to reuse a TOTP code results in an error' do
      secret = 'abcdefghi'
      user = create(:user, :signed_up, otp_secret_key: secret)
      otp = generate_totp_code(secret)

      Timecop.freeze do
        sign_in_user(user)
        fill_in 'code', with: otp
        click_submit_default

        expect(current_path).to eq(account_path)

        first(:link, t('links.sign_out')).click

        sign_in_user(user)
        fill_in 'code', with: otp
        click_submit_default

        expect(page).to have_content(t('two_factor_authentication.invalid_otp'))
        expect(current_path).to eq login_two_factor_authenticator_path
      end
    end
  end

  it 'generates a 404 with bad otp_delivery_preference' do
    sign_in_before_2fa
    visit '/login/two_factor/bad'

    expect(page.status_code).to eq(404)
  end

  describe 'visiting OTP delivery and verification pages after fully authenticating' do
    it 'redirects to profile page' do
      sign_in_and_2fa_user
      visit login_two_factor_path(otp_delivery_preference: 'sms')

      expect(current_path).to eq account_path

      visit user_two_factor_authentication_path

      expect(current_path).to eq account_path
    end
  end

  describe 'clicking the logo image during 2fa process' do
    it 'returns them to the home page' do
      user = create(:user, :signed_up)
      sign_in_user(user)
      click_link 'login.gov'
      expect(current_path).to eq root_path
    end
  end

  describe 'clicking footer links during 2FA' do
    it 'renders the requested pages' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      click_link t('links.help')

      expect(current_url).to eq MarketingSite.help_url

      visit login_two_factor_path(otp_delivery_preference: 'sms')
      click_link t('links.contact')

      expect(current_url).to eq MarketingSite.contact_url

      visit login_two_factor_path(otp_delivery_preference: 'sms')
      click_link t('links.privacy_policy')

      expect(current_url).to eq MarketingSite.privacy_url
    end
  end
end
