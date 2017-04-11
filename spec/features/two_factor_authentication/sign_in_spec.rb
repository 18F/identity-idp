require 'rails_helper'

include Features::ActiveJobHelper

feature 'Two Factor Authentication' do
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
  end

  def attempt_to_bypass_2fa_setup
    visit profile_path
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

      submit_prefilled_otp_code

      expect(current_path).to eq profile_path
    end

    def attempt_to_bypass_2fa
      visit profile_path
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

    context 'user enters OTP incorrectly 3 times', js: true do
      it 'locks the user out and leaves user on the page during entire lockout period' do
        allow(Figaro.env).to receive(:session_check_frequency).and_return('1')
        allow(Figaro.env).to receive(:session_check_delay).and_return('2')

        user = create(:user, :signed_up)
        sign_in_before_2fa(user)

        3.times do
          fill_in('code', with: 'bad-code')
          click_button t('forms.buttons.submit.default')
        end

        expect(page).to have_content t('titles.account_locked')
        expect(page).to have_content(/4:5\d/)

        # let lockout period expire
        UpdateUser.new(
          user: user,
          attributes: {
            second_factor_locked_at: Time.zone.now - (Devise.direct_otp_valid_for + 1.second),
          }
        ).call

        sign_in_before_2fa(user)
        click_button t('forms.buttons.submit.default')

        expect(current_path).to eq profile_path
      end
    end

    context 'user signs in while locked out' do
      it 'signs the user out and lets them know they are locked out' do
        user = create(:user, :signed_up, second_factor_locked_at: Time.zone.now - 1.minute)
        allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
        signin(user.email, user.password)

        expect(page).to have_content t('devise.two_factor_authentication.' \
                                       'max_otp_login_attempts_reached')

        visit profile_path
        expect(current_path).to eq root_path
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

      expect(current_path).to eq profile_path
    end
  end

  describe 'visiting OTP delivery and verification pages after fully authenticating' do
    it 'redirects to profile page' do
      sign_in_and_2fa_user
      visit login_two_factor_path(otp_delivery_preference: 'sms')

      expect(current_path).to eq profile_path

      visit user_two_factor_authentication_path

      expect(current_path).to eq profile_path
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
