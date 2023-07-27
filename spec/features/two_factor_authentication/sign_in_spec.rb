require 'rails_helper'

RSpec.feature 'Two Factor Authentication' do
  describe 'When the user has not set up 2FA' do
    scenario 'user is prompted to set up two factor authentication at account creation' do
      user = sign_in_before_2fa

      attempt_to_bypass_2fa_setup

      expect(current_path).to eq authentication_methods_setup_path

      select_2fa_option('phone')

      click_continue

      expect(page).
        to have_content t('titles.phone_setup')

      send_one_time_code_without_entering_phone_number

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
        select 'Bahamas', from: 'new_phone_form_international_code'
        fill_in 'new_phone_form_phone', with: unsupported_phone
        click_send_one_time_code

        expect(current_path).to eq phone_setup_path
        expect(page).to have_content t(
          'two_factor_authentication.otp_delivery_preference.voice_unsupported',
          location: 'Bahamas',
        )

        click_on t('two_factor_authentication.choose_another_option')

        expect(current_path).to eq authentication_methods_setup_path
      end
    end

    context 'with international phone that does not support voice delivery' do
      scenario 'updates international code as user types', :js do
        sign_in_before_2fa
        select_2fa_option(:phone)

        click_send_one_time_code
        expect(page.find(':focus')).to match_css('.phone-input__number')
        expect(page).to have_content(t('errors.messages.phone_required'))

        fill_in 'new_phone_form_phone', with: '+81 54 354 3643'
        expect(page.find('#new_phone_form_international_code', visible: false).value).to eq 'JP'

        fill_in 'new_phone_form_phone', with: '+81 54 354 364'

        click_send_one_time_code
        expect(page.find(':focus')).to match_css('.phone-input__number')
        expect(page).to have_content(t('errors.messages.invalid_phone_number.international'))

        fill_in 'new_phone_form_phone', with: ''

        click_send_one_time_code
        expect(page.find(':focus')).to match_css('.phone-input__number')
        expect(page).to have_content(t('errors.messages.phone_required'))

        fill_in 'new_phone_form_phone', with: '+353 537'

        click_send_one_time_code
        expect(page.find(':focus')).to match_css('.phone-input__number')
        expect(page).to have_content(t('errors.messages.invalid_phone_number.international'))
        expect(page.find('#new_phone_form_international_code', visible: false).value).to eq 'IE'

        fill_in 'new_phone_form_phone', with: ''

        click_send_one_time_code
        expect(page.find(':focus')).to match_css('.phone-input__number')
        expect(page).to have_content(t('errors.messages.phone_required'))
        fill_in 'new_phone_form_phone', with: '+81 54354'

        click_send_one_time_code
        expect(page.find(':focus')).to match_css('.phone-input__number')
        expect(page).to have_content(t('errors.messages.invalid_phone_number.international'))

        expect(page.find('#new_phone_form_international_code', visible: false).value).to eq 'JP'
      end

      scenario 'updates enabled delivery options based on deliverability to the country', :js do
        sign_in_before_2fa
        select_2fa_option(:phone)

        option_with_none_disabled = page.find(
          '.phone-input__international-code :nth-child(1)',
          visible: :all,
        )
        option_with_none_disabled.execute_script('this.dataset.supportsVoice = "true"')
        option_with_none_disabled.execute_script('this.dataset.supportsSms = "true"')
        option_with_disabled_voice = page.find(
          '.phone-input__international-code :nth-child(2)',
          visible: :all,
        )
        option_with_disabled_voice.execute_script('this.dataset.supportsVoice = "false"')
        option_with_disabled_voice.execute_script('this.dataset.supportsSms = "true"')
        option_with_disabled_sms = page.find(
          '.phone-input__international-code :nth-child(3)',
          visible: :all,
        )
        option_with_disabled_sms.execute_script('this.dataset.supportsVoice = "true"')
        option_with_disabled_sms.execute_script('this.dataset.supportsSms = "false"')
        option_with_all_disabled = page.find(
          '.phone-input__international-code :nth-child(4)',
          visible: :all,
        )
        option_with_all_disabled.execute_script('this.dataset.supportsVoice = "false"')
        option_with_all_disabled.execute_script('this.dataset.supportsSms = "false"')

        sms_radio = page.find('.js-otp-delivery-preference[value="sms"]', visible: :all)
        voice_radio = page.find('.js-otp-delivery-preference[value="voice"]', visible: :all)

        expect(sms_radio).to match_css(':checked')

        select_country_and_type_phone_number(country: option_with_disabled_sms['value'].downcase)
        expect(page).to have_content(
          t(
            'two_factor_authentication.otp_delivery_preference.sms_unsupported',
            location: option_with_disabled_sms['data-country-name'],
          ),
        )
        expect(sms_radio).not_to match_css(':checked')
        expect(voice_radio).to match_css(':checked')

        select_country_and_type_phone_number(country: option_with_disabled_voice['value'].downcase)
        expect(page).to have_content(
          t(
            'two_factor_authentication.otp_delivery_preference.voice_unsupported',
            location: option_with_disabled_voice['data-country-name'],
          ),
        )
        expect(sms_radio).to match_css(':checked')
        expect(voice_radio).not_to match_css(':checked')

        select_country_and_type_phone_number(country: option_with_all_disabled['value'].downcase)
        expect(page).to have_content(
          t(
            'two_factor_authentication.otp_delivery_preference.no_supported_options',
            location: option_with_all_disabled['data-country-name'],
          ),
        )
        expect(sms_radio).not_to match_css(':checked')
        expect(voice_radio).not_to match_css(':checked')

        select_country_and_type_phone_number(country: option_with_none_disabled['value'].downcase)
        expect(page).to have_content(
          t('two_factor_authentication.otp_delivery_preference.instruction'),
        )
      end

      scenario 'allows a user to continue typing even if a number is invalid', :js do
        sign_in_before_2fa
        select_2fa_option(:phone)

        # Because javascript is enabled and we do some fancy pants stuff with radio buttons, we need
        # to click on the radio buttons parent to make a selection
        voice_radio_button = page.find(
          '#new_phone_form_otp_delivery_preference_voice', visible: false
        )
        voice_radio_button.find(:xpath, '..').click

        select_country_and_type_phone_number(country: 'us', number: '12345678901234567890')

        expect(phone_field.value).to eq('12345678901234567890')
      end
    end
  end

  def phone_field
    find('#new_phone_form_phone')
  end

  def select_country_and_type_phone_number(country:, number: '')
    find('.iti__flag').click
    find(".iti__country[data-country-code='#{country}']").click
    phone_field.send_keys(number)
  end

  def attempt_to_bypass_2fa_setup
    visit account_path
  end

  def send_one_time_code_without_entering_phone_number
    click_send_one_time_code
  end

  def submit_2fa_setup_form_with_empty_string_phone
    fill_in 'new_phone_form_phone', with: ''
    click_send_one_time_code
  end

  def submit_2fa_setup_form_with_invalid_phone
    fill_in 'new_phone_form_phone', with: 'five one zero five five five four three two one'
    click_send_one_time_code
  end

  def submit_2fa_setup_form_with_valid_phone
    fill_in 'new_phone_form_phone', with: '703-555-1212'
    click_send_one_time_code
  end

  describe 'When the user has already set up 2FA' do
    it 'automatically sends the OTP to the preferred delivery method' do
      user = create(:user, :fully_registered)
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
      user = create(:user, :fully_registered)
      sign_in_before_2fa(user)
      click_link t('links.cancel')

      expect(current_path).to eq root_path
    end

    scenario 'user does not have to focus on OTP field', js: true do
      user = create(:user, :fully_registered)
      sign_in_before_2fa(user)

      input = page.find_field(t('components.one_time_code_input.label'))
      expect(page.evaluate_script('document.activeElement.id')).to eq(input[:id])
    end

    it 'validates OTP format', js: true do
      user = create(:user, :fully_registered)
      sign_in_before_2fa(user)

      input = page.find_field(t('components.one_time_code_input.label'))

      # Invalid: Unsupported characters
      input.fill_in with: 'BADBAD'
      click_submit_default
      expect(page).to have_content(t('errors.messages.otp_format'))

      # Invalid: Not enough characters, with prefix
      fill_in t('components.one_time_code_input.label'), with: '#12345'
      click_submit_default
      expect(page).to have_content(t('errors.messages.otp_format'))

      # Invalid: Not enough characters, without prefix
      fill_in t('components.one_time_code_input.label'), with: '12345'
      click_submit_default
      expect(page).to have_content(t('errors.messages.otp_format'))

      # Valid: Enough characters, with prefix
      input.fill_in with: '#123456'
      expect(input.value).to eq('#123456')
      page.evaluate_script('document.activeElement.closest("form").reportValidity()')
      expect(page).not_to have_content(t('errors.messages.otp_format'))

      # Valid: Enough characters, without prefix
      input.fill_in with: '123456'
      expect(input.value).to eq('123456')
      page.evaluate_script('document.activeElement.closest("form").reportValidity()')
      expect(page).not_to have_content(t('errors.messages.otp_format'))
    end

    scenario 'the user changes delivery method' do
      user = create(:user, :fully_registered, otp_delivery_preference: :sms)
      sign_in_before_2fa(user)

      choose_another_security_option('voice')

      expect(Telephony::Test::Message.messages.length).to eq(1)
      expect(Telephony::Test::Call.calls.length).to eq(1)
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
      user = create(:user, :fully_registered, :with_piv_or_cac, :with_authentication_app)
      sign_in_before_2fa(user)

      expect(current_path).to eq login_two_factor_piv_cac_path

      choose_another_security_option('auth_app')

      expect(current_path).to eq login_two_factor_authenticator_path
    end

    scenario 'user can cancel PIV/CAC process' do
      user = create(:user, :fully_registered, :with_piv_or_cac)
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

      visit_piv_cac_service(
        login_two_factor_piv_cac_path,
        uuid: user.piv_cac_configurations.first.x509_dn_uuid,
        dn: 'C=US, O=U.S. Government, OU=DoD, OU=PKI, CN=DOE.JOHN.1234',
        nonce: nonce,
      )
      expect(current_path).to eq account_path
    end

    scenario 'user uses incorrect PIV/CAC as their second factor' do
      stub_piv_cac_service

      user = user_with_piv_cac
      sign_in_before_2fa(user)

      nonce = visit_login_two_factor_piv_cac_and_get_nonce

      visit_piv_cac_service(
        login_two_factor_piv_cac_path,
        uuid: user.piv_cac_configurations.first.x509_dn_uuid + 'X',
        dn: 'C=US, O=U.S. Government, OU=DoD, OU=PKI, CN=DOE.JOHN.12345',
        nonce: nonce,
      )
      expect(current_path).to eq login_two_factor_piv_cac_path
      expect(page).to have_content(t('two_factor_authentication.invalid_piv_cac'))
    end

    context 'user with Voice preference sends SMS, causing a Telephony error' do
      let(:user) do
        create(
          :user, :fully_registered,
          otp_delivery_preference: 'voice',
          with: { phone: '+12255551000', delivery_preference: 'voice' }
        )
      end
      let(:otp_rate_limiter) do
        OtpRateLimiter.new(user: user, phone_confirmed: true, phone: '+12255551000')
      end

      it 'does not change their OTP delivery preference' do
        allow(OtpRateLimiter).to receive(:new).and_return(otp_rate_limiter)
        allow(otp_rate_limiter).to receive(:exceeded_otp_send_limit?).
          and_return(false)

        sign_in_user(user)

        expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'voice')

        choose_another_security_option('sms')

        expect(page).to have_content I18n.t('telephony.error.friendly_message.generic')
        expect(user.reload.otp_delivery_preference).to eq 'voice'
      end
    end
  end

  describe 'when the user is not piv/cac enabled' do
    it 'has no link to piv/cac during login' do
      user = create(:user, :fully_registered)
      sign_in_before_2fa(user)

      expect(page).not_to have_link(t('two_factor_authentication.piv_cac_fallback.question'))
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
      user = create(:user, :fully_registered)
      sign_in_before_2fa(user)
      click_link t('links.cancel')

      expect(current_path).to eq root_path
    end

    scenario 'attempting to reuse a TOTP code results in an error' do
      secret = 'abcdefghi'
      user = create(:user, :fully_registered, :with_authentication_app)
      Db::AuthAppConfiguration.create(user, secret, nil, 'foo')
      otp = generate_totp_code(secret)

      freeze_time do
        sign_in_user(user)
        fill_in 'code', with: otp
        click_submit_default

        expect(current_path).to eq(account_path)

        set_new_browser_session
        sign_in_user(user)
        fill_in 'code', with: otp
        click_submit_default

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
      user = create(:user, :fully_registered)
      sign_in_user(user)
      click_link 'Login.gov'
      expect(current_path).to eq root_path
    end
  end

  describe 'clicking footer links during 2FA' do
    it 'renders the requested pages' do
      user = create(:user, :fully_registered)
      sign_in_before_2fa(user)
      click_link t('links.help'), match: :first

      expect(current_url).to eq MarketingSite.help_url

      visit login_two_factor_path(otp_delivery_preference: 'sms')
      click_link t('links.contact'), match: :first

      expect(current_url).to eq MarketingSite.contact_url

      visit login_two_factor_path(otp_delivery_preference: 'sms')
      click_link t('links.privacy_policy'), match: :first

      expect(current_url).to eq MarketingSite.security_and_privacy_practices_url
    end
  end

  describe 'webauthn_platform' do
    include WebAuthnHelper

    before do
      allow(WebauthnVerificationForm).to receive(:domain_name).and_return('localhost:3000')
    end

    let!(:webauthn_configuration) do
      create(
        :webauthn_configuration,
        credential_id: credential_id,
        credential_public_key: credential_public_key,
        platform_authenticator: true,
        user: user,
      )
    end
    let(:user) do
      create(:user)
    end

    context 'sign in' do
      context 'with platform auth sign up enabled' do
        before do
          allow(IdentityConfig.store).to receive(:platform_auth_set_up_enabled).and_return(true)
        end

        it 'allows user to be signed in without issue' do
          mock_webauthn_verification_challenge

          sign_in_user(webauthn_configuration.user)
          mock_successful_webauthn_authentication { click_webauthn_authenticate_button }

          expect(page).to have_current_path(account_path)
        end
      end

      context 'with platform auth sign up disabled' do
        before do
          allow(IdentityConfig.store).to receive(:platform_auth_set_up_enabled).and_return(false)
        end

        it 'allows user to be signed in without issue' do
          mock_webauthn_verification_challenge

          sign_in_user(webauthn_configuration.user)
          mock_successful_webauthn_authentication { click_webauthn_authenticate_button }

          expect(page).to have_current_path(account_path)
        end
      end
    end
  end

  describe 'rate limiting' do
    let(:max_attempts) { 2 }
    let(:user) { create(:user, :fully_registered) }
    before do
      allow(IdentityConfig.store).to receive(:login_otp_confirmation_max_attempts).
        and_return(max_attempts)
    end

    def wrong_phone_otp
      loop do
        code = rand(100000...999999).to_s
        return code if code != last_phone_otp
      end
    end

    def submit_wrong_otp
      fill_in t('components.one_time_code_input.label'), with: wrong_phone_otp
      click_submit_default
    end

    it 'locks the user from further attempts after exceeding the configured max' do
      sign_in_before_2fa(user)
      max_attempts.times { submit_wrong_otp }

      expect(page).to have_content(t('titles.account_locked'))

      # Users session should be terminated and they should still be locked out if they sign in again
      within('.page-header') { click_on APP_NAME }
      fill_in_credentials_and_submit(user.email_addresses.first.email, user.password)
      expect(page).to have_content(t('titles.account_locked'))
    end

    context 'when the user is locked out' do
      let(:max_attempts) { 1 }

      before do
        sign_in_before_2fa(user)
        submit_wrong_otp
      end

      it 'allows the user to sign in again after lockout has expired' do
        travel (IdentityConfig.store.lockout_period_in_minutes - 1).minutes do
          signin(user.email_addresses.first.email, user.password)
          expect(page).to have_content(t('titles.account_locked'))
        end

        travel (IdentityConfig.store.lockout_period_in_minutes + 1).minutes do
          signin(user.email_addresses.first.email, user.password)
          expect(page).to have_content(t('two_factor_authentication.header_text'))
        end
      end
    end
  end
end
