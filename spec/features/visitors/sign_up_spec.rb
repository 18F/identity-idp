require 'rails_helper'

# Feature: Sign up
#   As a visitor
#   I want to sign up
#   So I can visit protected areas of the site

VALID_PASSWORD = 'Val!dPassw0rd'.freeze
INVALID_PASSWORD = 'asdf'.freeze

feature 'Sign Up', devise: true do
  # Scenario: Visitor can sign up with valid email address
  #   Given I am not signed in
  #   When I sign up with a valid email address
  #   Then I see a message that I need to confirm my email address
  scenario 'visitor can sign up with valid email address' do
    email = 'test@example.com'
    sign_up_with(email)
    expect(page).to have_content(
      t('devise.registrations.signed_up_but_unconfirmed.message_start') +
      " #{email}. " +
      t('devise.registrations.signed_up_but_unconfirmed.message_end')
    )
  end

  # Scenario: Visitor can sign up and confirm with valid email address and password
  #   Given I am not signed in
  #   When I sign up with a valid email address and click my confirmation link
  #   Then I see a message letting me know I need to set a password to finish creating my account
  #   And when I set a valid password
  #   Then I am prompted to set up 2FA without any flash messages
  scenario 'visitor can sign up and confirm a valid email' do
    sign_up_with('test@example.com')

    confirm_last_user

    expect(page).to have_content t('devise.confirmations.confirmed_but_must_set_password')
    expect(page).to have_title t('titles.confirmations.show')
    expect(page).to have_content t('forms.confirmation.show_hdr')

    fill_in 'password_form_password', with: VALID_PASSWORD
    click_button 'Submit'

    expect(current_url).to eq users_otp_url
    expect(page).to_not have_content t('devise.confirmations.confirmed')
    expect(page).to_not have_content t('devise.confirmations.confirmed_but_must_set_password')
  end

  scenario 'it sets reset_requested_at to nil after password confirmation' do
    sign_up_with_and_set_password_for('test@example.com')

    user = User.find_by_email('test@example.com')

    expect(user.reset_requested_at).to be_nil
  end

  context 'visitor can sign up and confirm a valid mobile for OTP' do
    before do
      sign_up_with_and_set_password_for('test@example.com')
      fill_in 'Mobile', with: '555-555-5555'
      click_button 'Submit'
      @user = User.find_by_email('test@example.com')
    end

    it 'updates mobile_confirmed_at and redirects to profile after confirmation' do
      fill_in 'Secure one-time password', with: @user.direct_otp
      click_button 'Submit'

      expect(@user.reload.mobile_confirmed_at).to be_present
      expect(current_path).to eq profile_index_path
    end

    it 'does not enable 2FA until correct OTP is entered' do
      fill_in 'Secure one-time password', with: '12345678'
      click_button 'Submit'

      expect(@user.reload.two_factor_enabled?).to be false
    end

    it 'provides user with link to type in a phone number so they are not locked out' do
      click_link 'entering it again'
      expect(current_path).to eq users_otp_path
    end

    it 'disables OTP lockout during account creation' do
      Devise.max_login_attempts.times do
        fill_in 'Secure one-time password', with: '12345678'
        click_button 'Submit'
      end

      expect(page).to_not have_content t('titles.account_locked')
      visit user_two_factor_authentication_path
      expect(current_path).to eq user_two_factor_authentication_path
    end

    it 'informs the user that the OTP code is sent to the mobile' do
      expect(page).
        to have_content(
          'A one-time passcode has been sent to ***-***-5555. ' \
          'Please enter the code that you received. Each code is valid for 5 minutes. ' \
          'If you do not receive a code within this time, please request a new one.'
        )
    end

    # JJG - I think we should go as far as making sure the user enters
    # a new number and that the OTP is sent to the new number.
    it 'allows user to enter new number if they Sign Out before confirming' do
      click_link(t('links.sign_out'))
      signin(@user.reload.email, VALID_PASSWORD)
      expect(current_path).to eq users_otp_path
    end
  end

  context "visitor tries to sign up with another user's mobile for OTP" do
    before do
      @existing_user = create(:user, :signed_up)
      sign_up_with_and_set_password_for('test@example.com')
      fill_in 'Mobile', with: @existing_user.mobile
      click_button 'Submit'
      @user = User.find_by_email('test@example.com')
    end

    it 'pretends the mobile is valid and prompts to confirm the number' do
      expect(current_path).to eq user_two_factor_authentication_path
      expect(page).
        to have_content('A one-time passcode has been sent to ***-***-1212.')
    end

    it 'does not confirm the new number with an invalid OTP' do
      fill_in 'Secure one-time password', with: 'foobar'
      click_button 'Submit'

      expect(@user.reload.mobile_confirmed_at).to be_nil
      expect(page).to have_content t('devise.two_factor_authentication.attempt_failed')
      expect(current_path).to eq user_two_factor_authentication_path
    end
  end

  scenario 'visitor is redirected back to password form when password is blank' do
    sign_up_with('test@example.com')
    confirm_last_user
    fill_in 'password_form_password', with: ''
    click_button 'Submit'

    expect(page).to have_content "can't be blank"
    expect(current_url).to eq confirm_url
  end

  context 'password field is blank when JS is on', js: true do
    before do
      User.create!(email: 'test@example.com')
      confirm_last_user
    end

    it 'shows error message when password is blank' do
      fill_in 'password_form_password', with: ''
      click_button 'Submit'

      expect(page).to have_content 'Please fill in all required fields'
    end
  end

  scenario 'password strength indicator hidden when JS is off' do
    sign_up_with('test@example.com')
    confirm_last_user

    expect(page).to have_css('#pw-strength-cntnr.hide')
  end

  context 'password strength indicator when JS is on', js: true do
    before do
      User.create!(email: 'test@example.com')
      confirm_last_user
    end

    it 'is visible on page (not have "hide" class)' do
      expect(page).to_not have_css('#pw-strength-cntnr.hide')
    end

    it 'updates as password changes' do
      expect(page).to have_content '...'

      fill_in 'password_form_password', with: 'password'
      expect(page).to have_content 'Very weak'

      fill_in 'password_form_password', with: 'this is a great sentence'
      expect(page).to have_content 'Great'
    end

    it 'has dynamic password strength feedback' do
      expect(page).to have_content '...'

      fill_in 'password_form_password', with: 'password'
      expect(page).to have_content 'This is a top-10 common password'
    end
  end

  scenario 'password visibility toggle when JS is on', js: true do
    sign_up_with('test@example.com')
    confirm_last_user

    expect(page).to have_css('#pw-toggle')

    click_button 'Show'
    expect(page).to have_content 'Hide'
  end

  scenario 'visitor is redirected back to password form when password is invalid' do
    sign_up_with('test@example.com')
    confirm_last_user
    fill_in 'password_form_password', with: 'Q!2e'
    click_button 'Submit'

    expect(page).to have_content('characters')
    expect(current_url).to eq confirm_url
  end

  context 'confirmed user is signed in and tries to confirm again' do
    it 'redirects the user to the profile' do
      sign_up_and_2fa('test@example.com')

      visit user_confirmation_url(confirmation_token: @raw_confirmation_token)

      expect(current_url).to eq profile_index_url
    end
  end

  # Scenario: Visitor cannot sign up with invalid email address
  #   Given I am not signed in
  #   When I sign up with an invalid email address
  #   Then I see an invalid email message
  scenario 'visitor cannot sign up with invalid email address' do
    sign_up_with('bogus')
    expect(page).to have_content t('valid_email.validations.email.invalid')
  end

  scenario 'visitor cannot sign up with empty email address', js: true do
    sign_up_with('')

    expect(page).to have_content('Please fill in all required fields')
  end

  scenario 'visitor cannot sign up with email with invalid domain name' do
    invalid_addresses = [
      'foo@bar.com',
      'foo@example.com'
    ]
    allow(ValidateEmail).to receive(:mx_valid?).and_return(false)

    invalid_addresses.each do |email|
      sign_up_with(email)
      expect(page).to have_content t('valid_email.validations.email.invalid')
    end
  end

  scenario 'visitor cannot sign up with empty email address' do
    sign_up_with('')

    expect(page).to have_content(invalid_email_message)
  end

  # Scenario: Visitor tries to determine if email exists in the system
  #   Given I am not signed in
  #   When I sign up with an existing email address
  #   Then I can't tell whether or not the email exists
  #   And no email is sent to the existing user
  scenario 'visitor signs up with an email already in the system', email: true do
    user = create(:user, email: 'existing_user@example.com')
    sign_up_with('existing_user@example.com')

    expect(page).to have_content(
      t('devise.registrations.signed_up_but_unconfirmed.message_start') +
      " #{user.email}. " +
      t('devise.registrations.signed_up_but_unconfirmed.message_end')
    )
    expect(number_of_emails_sent).to eq 0
  end

  # Scenario: Visitor signs up but confirms with an expired token
  #   Given I am not signed in
  #   When I sign up with a email address and attempt to confirm with expired token
  #   Then I see a message that my confirmation token has expired
  #   And that I should request a new one
  scenario 'visitor signs up but confirms with an expired token' do
    allow(Devise).to receive(:confirm_within).and_return(24.hours)
    sign_up_with('test@example.com')
    confirm_last_user
    User.last.update(confirmation_sent_at: Time.current - 2.days)
    visit user_confirmation_url(confirmation_token: @raw_confirmation_token)

    expect(current_path).to eq user_confirmation_path
    expect(page).to have_content t(
      'errors.messages.confirmation_period_expired', period: '24 hours'
    )
  end

  # Scenario: Visitor signs up but confirms with an invalid token
  #   Given I am not signed in
  #   When I sign up with a email address and attempt to confirm with invalid token
  #   Then I see a message that the token is invalid
  scenario 'visitor signs up but confirms with an invalid token' do
    sign_up_with('test@example.com')
    raw_confirmation_token = Devise.token_generator.generate(User, :confirmation_token)

    User.last.update(
      confirmation_token: raw_confirmation_token, confirmation_sent_at: Time.current
    )
    visit '/users/confirmation?confirmation_token=invalid_token'

    expect(page).to have_content 'Confirmation token is invalid'
    expect(current_path).to eq user_confirmation_path
  end

  # Scenario: Visitor tries to spam an existing user
  #   When I resend confirmation instructions to an existing user
  #   Then the user does not receive an email
  context 'confirmation instructions sent to existing user', email: true do
    it 'does not send an email to the existing user' do
      sign_up_with_and_set_password_for('test@example.com')
      reset_email

      visit destroy_user_session_url

      click_link "Didn't receive confirmation instructions?"
      fill_in 'Email', with: 'test@example.com'
      click_button 'Resend confirmation instructions'

      expect(number_of_emails_sent).to eq 0
    end
  end

  # Scenario: Confirmed visitor confirms again while signed out
  #   Given I've confirmed my email, created a password, and signed out
  #   When I click the confirmation link in the email again
  #   Then I see a message that I've already confirmed
  #   And I am redirected to the sign in page
  context 'confirmed user clicks confirmation link while again signed out' do
    it 'redirects to sign in page with message that user is already confirmed' do
      sign_up_with_and_set_password_for('test@example.com')

      visit destroy_user_session_url

      visit "/users/confirmation?confirmation_token=#{@raw_confirmation_token}"

      expect(page).
        to have_content t('devise.confirmations.already_confirmed', action: 'Please sign in.')
      expect(current_url).to eq new_user_session_url
    end
  end
end
