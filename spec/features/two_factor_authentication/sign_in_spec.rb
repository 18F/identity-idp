require 'rails_helper'

feature 'Two Factor Authentication' do
  include Features::ActiveJobHelper

  describe 'When the user has not set up 2FA' do
    scenario 'user is prompted to set up two factor authentication at account creation' do
      user = sign_in_before_2fa

      attempt_to_bypass_2fa_setup

      expect(current_path).to eq phone_setup_path
      expect(page).
        to have_content t('devise.two_factor_authentication.two_factor_setup')

      send_security_code_without_entering_phone_number

      expect(current_path).to eq phone_setup_path

      submit_2fa_setup_form_with_empty_string_phone

      expect(page).to have_content invalid_phone_message

      submit_2fa_setup_form_with_invalid_phone

      expect(page).to have_content invalid_phone_message

      submit_2fa_setup_form_with_valid_phone_and_choose_phone_call_delivery

      expect(page).to_not have_content invalid_phone_message
      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'voice')
      expect(user.reload.phone).to_not eq '+1 (555) 555-1212'
      expect(user.voice?).to eq true
    end

    context 'user enters OTP incorrectly 3 times' do
      it 'locks the user out' do
        sign_in_before_2fa

        submit_2fa_setup_form_with_valid_phone_and_choose_phone_call_delivery
        3.times do
          fill_in('code', with: 'bad-code')
          click_button t('forms.buttons.submit.default')
        end

        expect(page).to have_content t('titles.account_locked')
      end
    end

    context 'with U.S. phone that does not support phone delivery method' do
      let(:unsupported_phone) { '242-555-5555' }

      scenario 'renders an error if a user submits with phone selected' do
        sign_in_before_2fa
        fill_in 'Phone', with: unsupported_phone
        choose 'Phone call'
        click_send_security_code

        expect(current_path).to eq(phone_setup_path)
        expect(page).to have_content t(
          'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
          location: 'Bahamas'
        )
      end

      scenario 'disables the phone option and displays a warning with js', :js do
        sign_in_before_2fa

        fill_in 'Phone', with: unsupported_phone
        phone_radio_button = page.find(
          '#user_phone_form_otp_delivery_preference_voice',
          visible: :all
        )

        expect(page).to have_content t(
          'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
          location: 'Bahamas'
        )
        expect(phone_radio_button).to be_disabled

        fill_in 'Phone', with: '555-555-5000'

        expect(page).not_to have_content t(
          'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
          location: 'Bahamas'
        )
        expect(phone_radio_button).to_not be_disabled
      end
    end

    context 'with international phone that does not support phone delivery' do
      scenario 'renders an error if a user submits with phone selected' do
        sign_in_before_2fa
        select 'Turkey +90', from: 'International code'
        fill_in 'Phone', with: '555-555-5000'
        choose 'Phone call'
        click_send_security_code

        expect(current_path).to eq(phone_setup_path)
        expect(page).to have_content t(
          'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
          location: 'Turkey'
        )
      end

      scenario 'disables the phone option and displays a warning with js', :js do
        sign_in_before_2fa
        select 'Turkey +90', from: 'International code'
        fill_in 'Phone', with: '+90 312 213 29 65'
        phone_radio_button = page.find(
          '#user_phone_form_otp_delivery_preference_voice',
          visible: :all
        )

        expect(page).to have_content t(
          'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
          location: 'Turkey'
        )
        expect(phone_radio_button).to be_disabled

        select 'Canada +1', from: 'International code'

        expect(page).not_to have_content t(
          'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
          location: 'Turkey'
        )
        expect(phone_radio_button).to_not be_disabled
      end

      scenario 'updates international code as user types', :js do
        sign_in_before_2fa
        fill_in 'Phone', with: '+81 54 354 3643'

        expect(page.find('#user_phone_form_international_code').value).to eq 'JP'

        fill_in 'Phone', with: '5376'
        select 'Morocco +212', from: 'International code'

        expect(find('#user_phone_form_phone').value).to eq '+212 (537) 6'

        fill_in 'Phone', with: '54354'
        select 'Japan +81', from: 'International code'

        expect(find('#user_phone_form_phone').value).to include '+81'
      end

      scenario 'does not allow the user to remove the international code after entering it', :js do
        sign_in_before_2fa
        fill_in 'Phone', with: '+81 54 354 3643'

        input = find('#user_phone_form_phone')
        input.send_keys(*([:backspace] * input.value.length))

        expect(input.value).to eq('+81 ')
      end

      scenario 'allows a user to continue typing even if a number is invalid', :js do
        sign_in_before_2fa
        select 'United States of America +1', from: 'International code'

        input = find('#user_phone_form_phone')
        input.send_keys('12345678901234567890')

        expect(input.value).to eq('+1 2345678901234567890')
      end
    end
  end

  def attempt_to_bypass_2fa_setup
    visit account_path
  end

  def send_security_code_without_entering_phone_number
    click_send_security_code
  end

  def submit_2fa_setup_form_with_empty_string_phone
    fill_in 'Phone', with: ''
    click_send_security_code
  end

  def submit_2fa_setup_form_with_invalid_phone
    fill_in 'Phone', with: 'five one zero five five five four three two one'
    click_send_security_code
  end

  def submit_2fa_setup_form_with_valid_phone_and_choose_phone_call_delivery
    fill_in 'Phone', with: '555-555-1212'
    choose 'Phone call'
    click_send_security_code
  end

  describe 'When the user has already set up 2FA' do
    it 'automatically sends the OTP to the preferred delivery method' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)

      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
      expect(page).
        to have_content t('devise.two_factor_authentication.header_text')

      attempt_to_bypass_2fa

      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')

      check 'remember_device'
      submit_prefilled_otp_code

      expect(current_path).to eq account_path
    end

    def attempt_to_bypass_2fa
      visit account_path
    end

    def submit_prefilled_otp_code
      click_button t('forms.buttons.submit.default')
    end

    scenario 'user can resend one-time password (OTP)' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      old_code = find('input[@name="code"]').value

      click_link t('links.two_factor_authentication.resend_code.sms')

      new_code = find('input[@name="code"]').value

      expect(old_code).not_to eq(new_code)
    end

    scenario 'user can cancel OTP process' do
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

      allow(VoiceOtpSenderJob).to receive(:perform_later)

      click_on t('links.two_factor_authentication.voice')

      expect(VoiceOtpSenderJob).to have_received(:perform_later)
    end

    scenario 'the user cannot change delivery method if phone is unsupported' do
      unsupported_phone = '+1 (242) 555-5000'
      user = create(:user, :signed_up, phone: unsupported_phone)
      sign_in_before_2fa(user)

      expect(page).to_not have_link t('links.two_factor_authentication.voice')
    end

    context 'user enters OTP incorrectly 3 times', js: true do
      it 'locks the user out and leaves user on the page during entire lockout period' do
        lockout_period = Figaro.env.lockout_period_in_minutes.to_i.minutes
        five_minute_countdown_regex = /4:5\d/

        user = create(:user, :signed_up)
        sign_in_user(user)

        3.times do
          fill_in('code', with: '000000')
          click_button t('forms.buttons.submit.default')
        end

        expect(page).to have_content t('titles.account_locked')
        expect(page).to have_content(five_minute_countdown_regex)

        # let lockout period expire
        UpdateUser.new(
          user: user,
          attributes: {
            second_factor_locked_at: Time.zone.now - (lockout_period + 1.minute),
          }
        ).call

        sign_in_user(user)
        fill_in('code', with: user.reload.direct_otp)
        click_button t('forms.buttons.submit.default')

        expect(page).to have_current_path account_path
      end
    end

    context 'user requests an OTP too many times within `findtime` minutes', js: true do
      it 'locks the user out and leaves user on the page during entire lockout period' do
        lockout_period = Figaro.env.lockout_period_in_minutes.to_i.minutes
        five_minute_countdown_regex = /4:5\d/

        user = create(:user, :signed_up)
        sign_in_before_2fa(user)

        Figaro.env.otp_delivery_blocklist_maxretry.to_i.times do
          click_link t('links.two_factor_authentication.resend_code.sms')
        end

        expect(page).to have_content t('titles.account_locked')
        expect(page).to have_content(five_minute_countdown_regex)
        expect(page).to have_content t('devise.two_factor_authentication.max_otp_requests_reached')

        visit root_path
        signin(user.email, user.password)

        expect(page).to have_content t('titles.account_locked')
        expect(page).to have_content(five_minute_countdown_regex)
        expect(page).
          to have_content t('devise.two_factor_authentication.max_generic_login_attempts_reached')

        # let lockout period expire
        Timecop.travel(lockout_period) do
          signin(user.email, user.password)

          expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
        end
      end
    end

    context 'findtime period is greater than lockout period' do
      it 'does not lock the user' do
        allow(Figaro.env).to receive(:otp_delivery_blocklist_findtime).and_return('10')
        lockout_period = Figaro.env.lockout_period_in_minutes.to_i.minutes
        user = create(:user, :signed_up)

        sign_in_before_2fa(user)

        Figaro.env.otp_delivery_blocklist_maxretry.to_i.times do
          click_link t('links.two_factor_authentication.resend_code.sms')
        end

        expect(page).to have_content t('titles.account_locked')

        # let lockout period expire
        Timecop.travel(lockout_period) do
          signin(user.email, user.password)

          expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
        end
      end
    end

    context 'user requests OTP several times but spaced out far apart' do
      it 'does not lock the user out' do
        max_attempts = Figaro.env.otp_delivery_blocklist_maxretry.to_i
        findtime = Figaro.env.otp_delivery_blocklist_findtime.to_i.minutes
        user = create(:user, :signed_up)

        sign_in_before_2fa(user)
        (max_attempts - 1).times do
          click_link t('links.two_factor_authentication.resend_code.sms')
        end
        click_submit_default

        expect(current_path).to eq account_path

        phone_fingerprint = Pii::Fingerprinter.fingerprint(user.phone)
        rate_limited_phone = OtpRequestsTracker.find_by(phone_fingerprint: phone_fingerprint)

        # let findtime period expire
        rate_limited_phone.update(otp_last_sent_at: Time.zone.now - (findtime + 1))

        visit destroy_user_session_url
        sign_in_before_2fa(user)

        expect(rate_limited_phone.reload.otp_send_count).to eq 1

        click_link t('links.two_factor_authentication.resend_code.sms')

        expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')

        click_submit_default

        expect(current_path).to eq account_path
      end
    end

    context '2 users with same phone number request OTP too many times within findtime' do
      it 'locks both users out' do
        allow(Figaro.env).to receive(:otp_delivery_blocklist_maxretry).and_return('3')
        first_user = create(:user, :signed_up, phone: '+1 703-555-1212')
        second_user = create(:user, :signed_up, phone: '+1 703-555-1212')
        max_attempts = Figaro.env.otp_delivery_blocklist_maxretry.to_i

        sign_in_before_2fa(first_user)
        click_link t('links.two_factor_authentication.resend_code.sms')

        expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')

        visit destroy_user_session_url

        sign_in_before_2fa(second_user)
        click_link t('links.two_factor_authentication.resend_code.sms')
        phone_fingerprint = Pii::Fingerprinter.fingerprint(first_user.phone)
        rate_limited_phone = OtpRequestsTracker.find_by(phone_fingerprint: phone_fingerprint)

        expect(current_path).to eq otp_send_path
        expect(rate_limited_phone.otp_send_count).to eq max_attempts

        visit account_path

        expect(current_path).to eq root_path

        visit destroy_user_session_url

        signin(first_user.email, first_user.password)

        expect(page).to have_content t('devise.two_factor_authentication.max_otp_requests_reached')

        visit account_path
        expect(current_path).to eq root_path
      end
    end

    context 'When setting up 2FA for the first time' do
      it 'enforces rate limiting only for current phone' do
        second_user = create(:user, :signed_up, phone: '+1 202-555-1212')

        sign_in_before_2fa
        max_attempts = Figaro.env.otp_delivery_blocklist_maxretry.to_i

        submit_2fa_setup_form_with_valid_phone_and_choose_phone_call_delivery

        max_attempts.times do
          click_link t('links.two_factor_authentication.resend_code.voice')
        end

        expect(page).to have_content t('titles.account_locked')

        visit root_path
        signin(second_user.email, second_user.password)

        expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
      end
    end

    context 'user signs in while locked out' do
      it 'signs the user out and lets them know they are locked out' do
        user = create(:user, :signed_up, second_factor_locked_at: Time.zone.now - 1.minute)
        allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
        signin(user.email, user.password)

        expect(page).to have_content t('devise.two_factor_authentication.' \
                                       'max_generic_login_attempts_reached')

        visit account_path
        expect(current_path).to eq root_path
      end

      it 'leaves the user on the lockout page during the entire lockout period', js: true do
        Timecop.freeze do
          allow(Figaro.env).to receive(:session_check_frequency).and_return('0')
          allow(Figaro.env).to receive(:session_check_delay).and_return('0')
          five_minute_countdown_regex = /4:5\d/
          allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
          user = create(:user, :signed_up, second_factor_locked_at: Time.zone.now)

          signin(user.email, user.password)

          expect(page).to have_content t('titles.account_locked')
          expect(page).to have_content(five_minute_countdown_regex)
        end
      end
    end

    context 'user enters correct OTP after incorrect OTP' do
      it 'does not display error message' do
        user = create(:user, :signed_up)
        sign_in_before_2fa(user)

        fill_in('code', with: 'bad-code')
        click_button t('forms.buttons.submit.default')
        fill_in('code', with: user.reload.direct_otp)
        click_button t('forms.buttons.submit.default')

        expect(page).
          to_not have_content t('devise.two_factor_authentication.invalid_otp')
      end
    end
  end

  describe 'when the user is TOTP enabled' do
    it 'allows SMS and Voice fallbacks' do
      user = create(:user, :signed_up, otp_secret_key: 'foo')
      sign_in_before_2fa(user)

      click_link t('devise.two_factor_authentication.totp_fallback.sms_link_text')

      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')

      visit login_two_factor_authenticator_path

      click_link t('devise.two_factor_authentication.totp_fallback.voice_link_text')

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
      user = build(:user, :signed_up, otp_secret_key: secret)
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

        expect(page).to have_content(t('devise.two_factor_authentication.invalid_otp'))
        expect(current_path).to eq login_two_factor_path(otp_delivery_preference: :authenticator)
      end
    end
  end

  # TODO: readd profile redirect, modal tests
  describe 'signing in when user does not already have personal key' do
    # For example, when migrating users from another DB
    it 'displays personal key and redirects to profile' do
      user = create(:user, :signed_up)
      UpdateUser.new(user: user, attributes: { personal_key: nil }).call

      sign_in_user(user)
      click_button t('forms.buttons.submit.default')
      fill_in 'code', with: user.reload.direct_otp
      click_button t('forms.buttons.submit.default')

      expect(user.reload.personal_key).not_to be_nil

      click_acknowledge_personal_key

      expect(current_path).to eq account_path
    end
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
      user = build_stubbed(:user, :signed_up)
      sign_in_user(user)
      find("img[alt='login.gov']").click
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
