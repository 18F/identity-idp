require 'rails_helper'

include Features::ActiveJobHelper

#   As a user
#   I want to sign in
#   So I can visit protected areas of the site
feature 'Two Factor Authentication', devise: true do
  describe 'When the user has not set a preferred method' do
    scenario 'user is prompted to setup two factor authentication at first sign in' do
      sign_in_user

      expect(current_path).to eq users_otp_path
      expect(page).
        to have_content t('devise.two_factor_authentication.select_two_factor')
    end

    scenario 'user must choose either email or mobile 2fa' do
      sign_up_with_and_set_password_for('test@example.com')
      uncheck 'Email'
      uncheck 'Mobile'
      click_button 'Submit'

      expect(current_path).to eq users_otp_path
      expect(page).to have_content t('upaya.forms.two_factor.make_selection')
      expect(page).
        to_not have_content t('devise.two_factor_authentication.please_confirm')
    end

    scenario 'user can set email as their preferred method' do
      sign_in_user
      check('Email')
      uncheck 'Mobile'
      click_button 'Submit'

      expect(current_path).to eq user_two_factor_authentication_path
      expect(page).
        to have_content t('devise.two_factor_authentication.please_confirm')
    end

    scenario 'user selects mobile but does not fill out a number' do
      sign_up_with_and_set_password_for('test@example.com')
      check('Mobile')
      click_button 'Submit'

      expect(current_path).to eq users_otp_path
      expect(page).
        to have_content t('devise.two_factor_authentication.select_two_factor')
    end

    scenario 'user attempts to circumnavigate OTP setup' do
      sign_in_user

      visit edit_user_registration_path

      expect(current_path).to eq users_otp_path
      expect(page).
        to have_content t('devise.two_factor_authentication.select_two_factor')
    end

    describe 'user selects Mobile' do
      scenario 'user leaves mobile blank' do
        sign_in_user
        check('Mobile')
        fill_in 'Mobile', with: ''
        click_button 'Submit'

        expect(page).to have_content invalid_mobile_message
      end

      scenario 'user enters an invalid number with no digits' do
        sign_in_user
        check('Mobile')
        fill_in 'Mobile', with: 'five one zero five five five four three two one'
        click_button 'Submit'

        expect(page).to have_content invalid_mobile_message
      end

      scenario 'user enters an invalid number with plus sign and no digits' do
        sign_in_user
        check('Mobile')
        fill_in 'Mobile', with: '+invalid'
        click_button 'Submit'

        expect(page).to have_content invalid_mobile_message
      end

      scenario 'user enters an invalid number with digits' do
        sign_in_user
        check('Mobile')
        fill_in 'Mobile', with: '55555512122'
        click_button 'Submit'

        expect(page).to have_content invalid_mobile_message
      end

      scenario 'user enters a valid number' do
        user = sign_in_user
        check('Mobile')
        fill_in 'Mobile', with: '555-555-1212'
        click_button 'Submit'

        expect(page).to_not have_content invalid_mobile_message
        expect(current_path).to eq user_two_factor_authentication_path
        expect(user.reload.mobile).to_not eq '+1 (555) 555-1212'
      end

      context 'user enters a valid number then changes their mind' do
        before do
          sign_up_with_and_set_password_for('test@example.com')
          @user = User.find_by_email('test@example.com')

          check('Mobile')
          fill_in 'Mobile', with: '555-555-1212'
          click_button 'Submit'
          visit users_otp_path

          reset_job_queues
          reset_email

          check('Email')
          uncheck('Mobile')
          click_button 'Submit'
        end

        it 'lets the user know an OTP was sent to their Email' do
          expect(page).to have_content "sent to #{@user.email}."
          expect(page).to_not have_content '555-1212'
        end

        it 'sends the OTP via email' do
          expect(last_email).to have_content('one-time password')
        end

        it 'deletes the unconfirmed_mobile' do
          expect(@user.reload.unconfirmed_mobile).to_not be_present
        end

        it 'does not update their number after they enter email OTP' do
          fill_in 'code', with: @user.reload.otp_code
          click_button 'Submit'
          expect(@user.reload.mobile).to_not be_present
        end

        it 'does not include a link to enter a number again' do
          expect(page).to_not have_link 'entering it again'
        end
      end
    end
  end # describe 'When the user has not set a preferred method'

  describe 'When the user has set a preferred method' do
    # Scenario: User with email 2fa is prompted for otp
    #   Given I exist as a user
    #   And I am not signed in and have email 2fa enabled
    #   When I sign in
    #   Then I am prompted for an emailed otp
    #   And I am allowed to fully sign in with a valid OTP
    context 'when the only method set is email' do
      before do
        my_user = create(:user, :signed_up)
        reset_job_queues
        reset_email
        @user = sign_in_user(my_user)
      end

      it 'displays error message when user enters invalid OTP' do
        fill_in 'code', with: @user.otp_code + 'invalidate_me'
        click_button 'Submit'
        expect(page).
          to have_content t('devise.two_factor_authentication.attempt_failed')
        expect(page).
          to have_content t('devise.two_factor_authentication.header_text')
      end

      it 'keeps count of invalid OTP attempts' do
        fill_in 'code', with: @user.otp_code + 'invalidate_me'
        click_button 'Submit'
        expect(@user.reload.second_factor_attempts_count).to equal(1)
      end

      it 'resets invalid OTP attempts count after entering valid OTP' do
        fill_in 'code', with: @user.otp_code + 'invalidate_me'
        click_button 'Submit'
        fill_in 'code', with: @user.otp_code
        click_button 'Submit'

        expect(@user.reload.second_factor_attempts_count).to equal(0)
      end

      it 'does not allow user to bypass entering OTP' do
        visit users_otp_path
        expect(current_path).to eq user_two_factor_authentication_path
      end

      it 'does not allow user to access OTP setup page after entering valid OTP' do
        fill_in 'code', with: @user.otp_code
        click_button 'Submit'
        visit users_otp_path

        expect(current_path).to eq dashboard_index_path
      end

      it 'does not allow user to access OTP prompt page after entering valid OTP' do
        fill_in 'code', with: @user.otp_code
        click_button 'Submit'
        visit user_two_factor_authentication_path

        expect(current_path).to eq dashboard_index_path
      end

      it 'displays an error message if the code field is empty', js: true do
        fill_in 'code', with: ''
        click_button 'Submit'

        expect(page).to have_content('Please fill in all required fields')
      end
    end

    describe 'Using Mobile' do
      # Scenario: User with mobile 2fa can fully sign in with otp
      #   Given I exist as a user
      #   And I am not signed in and have mobile 2fa enabled
      #   When I sign in
      #   Then I can fully sign in using the otp code that was texted to me
      scenario 'user can fully sign in with otp' do
        user ||= create(:user, :signed_up, :with_mobile)
        signin(user.email, user.password)

        # With 2fa, you are signed in but blocked on an otp challenge.
        expect(page).to have_content I18n.t 'devise.sessions.signed_in'
        expect(page).to have_content 'A one-time passcode has been sent'

        # Reach straight to the model to re-retrieve the OTP for testing
        # access checks of this feature. Lets us exclude testing the
        # sending logic.
        fill_in 'code', with: user.otp_code + 'invalidate_me'
        click_button 'Submit'
        expect(page).to have_content I18n.t('devise.two_factor_authentication.attempt_failed')
        expect(page).to have_content I18n.t('devise.two_factor_authentication.header_text')
        user.reload
        expect(user.second_factor_attempts_count).to equal(1)

        fill_in 'code', with: user.otp_code
        click_button 'Submit'
        user.reload

        expect(user.second_factor_attempts_count).to equal(0)
      end
    end # describe 'Using Mobile'

    scenario 'user is displayed the time remaining until their otp expires' do
      my_user = create(:user, :signed_up)
      sign_in_user(my_user)
      otp_drift_minutes = Devise.allowed_otp_drift_seconds / 60

      expect(page).to have_content "#{otp_drift_minutes} minutes"
    end

    scenario 'user can resend one-time password (OTP)' do
      user = create(:user, :signed_up)
      sign_in_user(user)
      click_link 'request a new passcode'

      expect(page).to have_content I18n.t('devise.two_factor_authentication.user.new_otp_sent')
    end

    scenario 'user attempts to circumnavigate OTP setup' do
      second_factor = SecondFactor.find_by_name 'Email'
      user = create(:user, :signed_up, second_factor_ids: second_factor.id)
      sign_in_user(user)
      visit edit_user_registration_path

      expect(page).to have_content I18n.t('devise.errors.messages.user_not_authenticated')
    end

    scenario 'user disables 2FA method' do
      user = sign_in_and_2fa_user

      user.second_factors = []
      user.save

      visit dashboard_index_path

      expect(current_path).to eq('/users/otp')
      expect(page).to have_content I18n.t('devise.two_factor_authentication.otp_setup')
      expect(page).to have_css('.alert')
    end

    scenario 'user enters OTP incorrectly 3 times and is locked out for otp drift period' do
      user = create(:user, :signed_up)
      signin(user.email, user.password)
      3.times do
        fill_in('code', with: 'bad-code')
        click_button('Submit')
      end

      expect(page).to have_content t('upaya.titles.account_locked')

      # let 10 minutes (otp drift time) magically pass
      user.update(second_factor_locked_at: Time.zone.now - (Devise.allowed_otp_drift_seconds + 1))

      signin(user.email, user.password)

      expect(page).to have_content I18n.t('devise.two_factor_authentication.header_text')
    end

    context 'user signs in while locked out' do
      it 'signs the user out and lets them know they are locked out' do
        user = create(:user, :signed_up)
        user.update(second_factor_locked_at: Time.zone.now - 1.minute)
        allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
        signin(user.email, user.password)

        expect(page).to have_content 'Your account is temporarily locked'

        visit edit_user_registration_path
        expect(current_path).to eq root_path
      end
    end
  end # describe 'When the user has set a preferred method'
end # feature 'Two Factor Authentication'
