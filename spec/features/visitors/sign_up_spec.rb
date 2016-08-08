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
      " #{email} " +
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

    expect(current_url).to eq phone_setup_url
    expect(page).to_not have_content t('devise.confirmations.confirmed')
    expect(page).to_not have_content t('devise.confirmations.confirmed_but_must_set_password')
  end

  scenario 'it sets reset_requested_at to nil after password confirmation' do
    user = sign_up_and_set_password

    expect(user.reset_requested_at).to be_nil
  end

  context 'visitor can sign up and confirm a valid mobile for OTP' do
    before do
      @user = sign_in_before_2fa
      fill_in 'Mobile', with: '555-555-5555'
      allow(Users::PhoneConfirmationController).
        to receive(:generate_confirmation_code).and_return('1234')
      click_button 'Submit'
    end

    it 'updates mobile_confirmed_at and redirects to profile after confirmation' do
      fill_in 'code', with: '1234'
      click_button 'Submit'

      expect(@user.reload.mobile_confirmed_at).to be_present
      expect(current_path).to eq profile_path
    end

    it 'allows user to resend confirmation code' do
      click_link 'Resend'
      expect(current_path).to eq phone_confirmation_path
    end

    it 'does not enable 2FA until correct OTP is entered' do
      fill_in 'code', with: '12345678'
      click_button 'Submit'

      expect(@user.reload.two_factor_enabled?).to be false
    end

    it 'provides user with link to type in a phone number so they are not locked out' do
      click_link 'Try again'
      expect(current_path).to eq phone_setup_path
    end

    it 'informs the user that the OTP code is sent to the mobile' do
      expect(page).to have_content('Please enter the code sent to +1 (555) 555-5555.')
    end

    it 'allows user to enter new number if they Sign Out before confirming' do
      click_link(t('links.sign_out'))
      signin(@user.reload.email, @user.password)
      expect(current_path).to eq phone_setup_path
    end
  end

  context "visitor tries to sign up with another user's mobile for OTP" do
    before do
      @existing_user = create(:user, :signed_up)
      @user = sign_in_before_2fa
      fill_in 'Mobile', with: @existing_user.mobile
      click_button 'Submit'
    end

    it 'pretends the mobile is valid and prompts to confirm the number' do
      expect(current_path).to eq phone_confirmation_path
      expect(page).to have_content('Please enter the code sent to +1 (202) 555-1212')
    end

    it 'does not confirm the new number with an invalid code' do
      fill_in 'code', with: 'foobar'
      click_button 'Submit'

      expect(@user.reload.mobile_confirmed_at).to be_nil
      expect(page).to have_content t('errors.invalid_confirmation_code')
      expect(current_path).to eq phone_confirmation_path
    end
  end

  scenario 'visitor is redirected back to password form when password is blank' do
    create(:user, :unconfirmed)
    confirm_last_user
    fill_in 'password_form_password', with: ''
    click_button 'Submit'

    expect(page).to have_content "can't be blank"
    expect(current_url).to eq confirm_url
  end

  context 'password field is blank when JS is on', js: true do
    before do
      create(:user, :unconfirmed)
      confirm_last_user
    end

    it 'shows error message when password is blank' do
      fill_in 'password_form_password', with: ''
      click_button 'Submit'

      expect(page).to have_content 'Please fill in this field'
    end
  end

  scenario 'password strength indicator hidden when JS is off' do
    create(:user, :unconfirmed)
    confirm_last_user

    expect(page).to have_css('#pw-strength-cntnr.hide')
  end

  context 'password strength indicator when JS is on', js: true do
    before do
      create(:user, :unconfirmed)
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
    create(:user, :unconfirmed)
    confirm_last_user

    expect(page).to have_css('#pw-toggle')
    expect(page).to have_css('input.password[type="password"]')

    check('Show password')

    expect(page).to_not have_css('input.password[type="password"]')
    expect(page).to have_css('input.password[type="text"]')
  end

  scenario 'visitor is redirected back to password form when password is invalid' do
    create(:user, :unconfirmed)
    confirm_last_user
    fill_in 'password_form_password', with: 'Q!2e'

    click_button 'Submit'

    expect(page).to have_content('characters')
    expect(current_url).to eq confirm_url
  end

  context 'confirmed user is signed in and tries to confirm again' do
    it 'redirects the user to the profile' do
      sign_up_and_2fa

      visit user_confirmation_url(confirmation_token: @raw_confirmation_token)

      expect(current_url).to eq profile_url
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

    expect(page).to have_content('Please fill in this field')
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
      " #{user.email} " +
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
    user = create(:user, :unconfirmed)
    confirm_last_user
    user.update(confirmation_sent_at: Time.current - 2.days)

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
    create(:user, :unconfirmed)
    visit '/users/confirmation?confirmation_token=invalid_token'

    expect(page).to have_content 'Confirmation token is invalid'
    expect(current_path).to eq user_confirmation_path
  end

  # Scenario: Visitor tries to spam an existing user
  #   When I resend confirmation instructions to an existing user
  #   Then the user does not receive an email
  context 'confirmation instructions sent to existing user', email: true do
    it 'does not send an email to the existing user' do
      user = create(:user)

      visit '/'
      click_link "Didn't receive confirmation instructions?"
      fill_in 'Email', with: user.email
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
      sign_up_and_set_password

      visit destroy_user_session_url

      visit "/users/confirmation?confirmation_token=#{@raw_confirmation_token}"

      expect(page).
        to have_content t('devise.confirmations.already_confirmed', action: 'Please sign in.')
      expect(current_url).to eq new_user_session_url
    end
  end
end
