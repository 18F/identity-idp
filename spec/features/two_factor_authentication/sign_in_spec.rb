require 'rails_helper'

include Features::ActiveJobHelper

#   As a user
#   I want to sign in
#   So I can visit protected areas of the site
feature 'Two Factor Authentication' do
  describe 'When the user has not setup 2FA' do
    scenario 'user is prompted to setup two factor authentication at first sign in' do
      sign_in_before_2fa

      expect(current_path).to eq phone_setup_path
      expect(page).
        to have_content t('devise.two_factor_authentication.two_factor_setup')
    end

    scenario 'user does not fill out a phone number when signing up' do
      sign_up_and_set_password
      click_button t('devise.two_factor_authentication.buttons.confirm_with_sms')

      expect(current_path).to eq phone_setup_path
    end

    scenario 'user attempts to circumnavigate OTP setup' do
      sign_in_before_2fa

      visit profile_path

      expect(current_path).to eq phone_setup_path
    end

    describe 'user selects phone' do
      scenario 'user leaves phone blank' do
        sign_in_before_2fa
        fill_in 'Phone', with: ''
        click_button t('devise.two_factor_authentication.buttons.confirm_with_sms')

        expect(page).to have_content invalid_phone_message
      end

      scenario 'user enters an invalid number with no digits' do
        sign_in_before_2fa
        fill_in 'Phone', with: 'five one zero five five five four three two one'
        click_button t('devise.two_factor_authentication.buttons.confirm_with_sms')

        expect(page).to have_content invalid_phone_message
      end

      scenario 'user enters a valid number' do
        user = sign_in_before_2fa
        fill_in 'Phone', with: '555-555-1212'
        click_button t('devise.two_factor_authentication.buttons.confirm_with_sms')

        expect(page).to_not have_content invalid_phone_message
        expect(current_path).to eq phone_confirmation_path
        expect(user.reload.phone).to_not eq '+1 (555) 555-1212'
      end
    end
  end # describe 'When the user has not set a preferred method'

  describe 'When the user has set a preferred method' do
    describe 'Using phone' do
      # Scenario: User with phone 2fa is prompted for otp
      #   Given I exist as a user
      #   And I am not signed in and have phone 2fa enabled
      #   When I sign in
      #   Then an OTP is sent to my phone
      #   And I am prompted to enter it
      context 'user is prompted for otp via phone only' do
        before do
          reset_job_queues
          @user = create(:user, :signed_up)
          reset_email
          sign_in_before_2fa(@user)
          click_button t('devise.two_factor_authentication.buttons.confirm_with_sms')
        end

        it 'lets the user know they are signed in' do
          expect(page).to have_content t('devise.sessions.signed_in')
        end

        it 'asks the user to enter an OTP' do
          expect(page).
            to have_content t('devise.two_factor_authentication.header_text')
        end

        it 'does not send an OTP via email' do
          expect(last_email).to_not have_content('one-time password')
        end

        it 'does not allow user to bypass entering OTP' do
          visit profile_path

          expect(current_path).to eq user_two_factor_authentication_path
        end

        it 'displays an error message if the code field is empty', js: true do
          fill_in 'code', with: ''
          click_button 'Submit'

          expect(page).to have_content('Please fill in this field')
        end
      end
    end

    scenario 'user can resend one-time password (OTP)' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      click_button t('devise.two_factor_authentication.buttons.confirm_with_sms')
      click_link 'Resend'

      expect(page).to have_content t('devise.two_factor_authentication.user.new_otp_sent')
    end

    scenario 'user who enters OTP incorrectly 3 times is locked out for OTP validity period' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      click_button t('devise.two_factor_authentication.buttons.confirm_with_sms')

      3.times do
        fill_in('code', with: 'bad-code')
        click_button('Submit')
      end

      expect(page).to have_content t('titles.account_locked')

      # let 10 minutes (otp validity period) magically pass
      user.update(second_factor_locked_at: Time.zone.now - (Devise.direct_otp_valid_for + 1.second))

      sign_in_before_2fa(user)
      click_button t('devise.two_factor_authentication.buttons.confirm_with_sms')

      expect(page).to have_content t('devise.two_factor_authentication.header_text')
    end

    context 'user signs in while locked out' do
      it 'signs the user out and lets them know they are locked out' do
        user = create(:user, :signed_up)
        user.update(second_factor_locked_at: Time.zone.now - 1.minute)
        allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
        sign_in_before_2fa(user)

        expect(page).to have_content 'Your account is temporarily locked'

        visit profile_path
        expect(current_path).to eq root_path
      end
    end
  end # describe 'When the user has set a preferred method'
end # feature 'Two Factor Authentication'
