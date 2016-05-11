require 'rails_helper'

# Feature: Password Recovery
#   As a user
#   I want to recover my password
#   So I can regain access to protected areas of the site
feature 'Password Recovery' do
  def reset_password_and_sign_back_in
    fill_in 'New password', with: 'NewVal!dPassw0rd'
    fill_in 'Confirm your new password', with: 'NewVal!dPassw0rd'
    click_button 'Change my password'
    fill_in 'Email', with: 'email@example.com'
    fill_in 'Password', with: 'NewVal!dPassw0rd'
    click_button 'Log in'
  end

  before(:each) do
    visit root_path
    click_link t('upaya.headings.passwords.forgot')
  end

  # Scenario: User can request a password reset link be sent to them
  #   Given I do not remember my password as a user
  #   When I complete the form on the password recovery page
  #   Then I receive an email
  context 'user can reset their password via email', email: true do
    before do
      user = create(:user, :signed_up)
      fill_in 'Email', with: user.email
      click_button 'Send me reset password instructions'
    end

    it 'uses a relevant email subject' do
      expect(last_email.subject).to eq 'Password reset instructions'
    end

    it 'includes a link to customer service in the email' do
      expect(last_email.body).
        to include 'at <a href="https://upaya.18f.gov/contact">'
    end

    it 'displays a localized notice' do
      expect(page).to have_content t('upaya.notices.password_reset')
    end

    it 'includes a link to reset the password in the email' do
      open_last_email
      click_first_link_in_email

      expect(current_path).to eq edit_user_password_path
    end

    it 'specifies how long the user has to reset the password based on Devise settings' do
      expect(last_email.body).
        to have_content "expires in #{Devise.reset_password_within / 3600} hours"
    end
  end

  # Scenario: User that has only confirmed their email can reset their password
  #   Given I have not created my password yet
  #   And I click the Forgot password? link and enter my email
  #   When I click the link in the password reset email
  #   Then I can set a new password
  context 'user with only email confirmation resets password', email: true do
    before do
      sign_up_with('email@example.com')
      open_last_email
      click_first_link_in_email
      reset_email
      visit root_path
      click_link t('upaya.headings.passwords.forgot')
      fill_in 'Email', with: 'email@example.com'
      click_button 'Send me reset password instructions'
      open_last_email
      click_first_link_in_email
    end

    it 'shows the password form' do
      expect(page).to have_content t('upaya.forms.confirmation.show_hdr')
    end
  end

  # Scenario: User that has only confirmed their email can reset their password
  #   Given I have not created my password yet
  #   And I go to new user confirmation page and enter my email
  #   When I click the link in the confirmation email
  #   Then I can set a new password
  context 'user with email confirmation resends confirmation', email: true do
    before do
      sign_up_with('email@example.com')
      open_last_email
      click_first_link_in_email
      reset_email
      visit new_user_confirmation_path
      fill_in 'Email', with: 'email@example.com'
      click_button 'Resend confirmation instructions'
      open_last_email
      click_first_link_in_email
    end

    it 'shows the password form' do
      expect(page).to have_content t('upaya.forms.confirmation.show_hdr')
    end
  end

  # Scenario: User that has only confirmed password can reset their password
  #   Given I have not set up 2FA yet
  #   And I click the Forgot password? link and enter my email
  #   When I click the link in the email
  #   Then I can set a new password
  context 'user with password confirmation resets password', email: true do
    before do
      sign_up_with('email@example.com')
      open_last_email
      click_first_link_in_email
      reset_email
      fill_in 'user[password]', with: 'ValidPassw0rd!'
      fill_in 'user[password_confirmation]', with: 'ValidPassw0rd!'
      click_button 'Submit'
      click_link(t('upaya.headings.log_out'), match: :first)
      visit root_path
      click_link t('upaya.headings.passwords.forgot')
      fill_in 'Email', with: 'email@example.com'
      click_button 'Send me reset password instructions'
      open_last_email
      click_first_link_in_email
    end

    it 'shows the password form' do
      expect(page).to have_content t('upaya.headings.passwords.change')
    end

    it 'keeps user signed out after they successfully reset their password' do
      fill_in 'New password', with: 'NewVal!dPassw0rd'
      fill_in 'Confirm your new password', with: 'NewVal!dPassw0rd'
      click_button 'Change my password'

      expect(current_path).to eq new_user_session_path
    end

    it 'prompts user to set up their 2FA options after signing back in' do
      reset_password_and_sign_back_in

      expect(current_path).to eq users_otp_path
    end
  end

  context 'user with invalid token cannot reset password', email: true do
    before do
      sign_up_with('email@example.com')
      open_last_email
      click_first_link_in_email
      reset_email
      fill_in 'user[password]', with: 'ValidPassw0rd!'
      fill_in 'user[password_confirmation]', with: 'ValidPassw0rd!'
      click_button 'Submit'
      click_link(t('upaya.headings.log_out'), match: :first)
      visit root_path
      click_link t('upaya.headings.passwords.forgot')
      fill_in 'Email', with: 'email@example.com'
      click_button 'Send me reset password instructions'
      visit edit_user_password_path(reset_password_token: 'invalid_token')
    end

    it 'redirects to new user password form' do
      expect(current_path).to eq new_user_password_path
    end

    it 'displays a flash error message' do
      expect(page).to have_content t('devise.passwords.invalid_token')
    end
  end

  # Scenario: User that has only confirmed 2FA can reset their password
  #   When I click the Forgot password? link and enter my email
  #   And I click the link in the email
  #   Then I can set a new password
  context 'user with 2FA confirmation resets password', email: true do
    before do
      sign_up_with('email@example.com')
      open_last_email
      click_first_link_in_email
      reset_email
      fill_in 'user[password]', with: 'ValidPassw0rd!'
      fill_in 'user[password_confirmation]', with: 'ValidPassw0rd!'
      click_button 'Submit'
      fill_in 'Mobile', with: '5555555555'
      click_button 'Submit'
      fill_in 'code', with: User.last.otp_code
      click_button 'Submit'
      click_link(t('upaya.headings.log_out'), match: :first)
      visit root_path
      click_link t('upaya.headings.passwords.forgot')
      fill_in 'Email', with: 'email@example.com'
      click_button 'Send me reset password instructions'
      open_last_email
      click_first_link_in_email
    end

    it 'shows the password form' do
      expect(page).to have_content t('upaya.headings.passwords.change')
    end

    it 'redirects user to dashboard after signing back in' do
      reset_password_and_sign_back_in
      fill_in 'code', with: User.last.otp_code
      click_button 'Submit'

      expect(current_path).to eq dashboard_index_path
    end
  end

  # Scenario: User can only submit valid email addresses
  #   Given I do not remember my password as a user
  #   When I complete the form with invalid email addresses
  #   Then I receive a useful error
  scenario 'user submits email address with invalid format' do
    invalid_addresses = [
      'user@domain-without-suffix',
      'Buy Medz 0nl!ne http://pharma342.onlinestore.com'
    ]
    allow(ValidateEmail).to receive(:mx_valid?).and_return(false)

    invalid_addresses.each do |email|
      fill_in 'Email', with: email
      click_button 'Send me reset password instructions'

      expect(page).to have_content t('valid_email.validations.email.invalid')
    end
  end

  scenario 'user submits email address with invalid domain name' do
    invalid_addresses = [
      'foo@bar.com',
      'foo@example.com'
    ]
    allow(ValidateEmail).to receive(:mx_valid?).and_return(false)

    invalid_addresses.each do |email|
      fill_in 'Email', with: email
      click_button 'Send me reset password instructions'

      expect(page).to have_content t('valid_email.validations.email.invalid')
    end
  end

  scenario 'user submits blank email address' do
    click_button 'Send me reset password instructions'

    expect(page).to have_content t('valid_email.validations.email.invalid')
  end

  scenario 'user submits blank email address and has JS turned on', js: true do
    click_button 'Send me reset password instructions'

    expect(page).to have_content 'Please fill in all required fields'
  end

  # Scenario: User is unable to determine if someone else's account exists
  #   Given I want to find out if an account exists
  #   When I complete the form on the password recovery page
  #   Then I still don't know if an account exists
  scenario 'user is unable to determine if account exists' do
    fill_in 'Email', with: 'no_account_exists@gmail.com'
    click_button 'Send me reset password instructions'
    expect(page).to have_content(I18n.t('devise.passwords.send_instructions'))
  end

  # Scenario: User can reset their password
  #   Given I do not remember my password as a user
  #   When I complete the form on the password recovery page
  #   Then I receive an email
  context 'user can reset their password' do
    before do
      @user = create(:user, :signed_up)

      fill_in 'Email', with: @user.email
      click_button 'Send me reset password instructions'

      raw_reset_token, db_confirmation_token =
        Devise.token_generator.generate(User, :reset_password_token)
      @user.update(reset_password_token: db_confirmation_token)

      visit edit_user_password_path(reset_password_token: raw_reset_token)
    end

    it 'lands on the reset password page' do
      expect(current_path).to eq edit_user_password_path
    end

    context 'when password form values are valid' do
      it 'changes the password, sends an email about the change, and does not sign the user in' do
        fill_in 'New password', with: 'NewVal!dPassw0rd'
        fill_in 'Confirm your new password', with: 'NewVal!dPassw0rd'
        click_button 'Change my password'

        expect(page).to have_content(I18n.t('devise.passwords.updated_not_active'))

        expect(last_email.subject).to eq 'Password change notification'

        visit edit_user_registration_path
        expect(current_path).to eq new_user_session_path
      end
    end

    it 'displays error when password fields are empty & JS is on', js: true do
      click_button 'Change my password'

      expect(page).to have_content 'Please fill in all required fields'
    end

    it 'displays field validation error when password fields are empty' do
      click_button 'Change my password'

      expect(page).to have_content "can't be blank"
    end

    it 'displays field validation error when password field is too short' do
      fill_in 'New password', with: '1234'
      click_button 'Change my password'

      expect(page).to have_content 'is too short (minimum is 8 characters)'
    end
  end

  # Scenario: User takes too long to click the reset password link
  #   Given I have waited too long to click the link in my email
  #   When I click the link
  #   Then I see a error message that tells me the token has expired
  #   And I am prompted to send instructions again
  scenario 'user takes too long to click the reset password link' do
    user = create(:user, :signed_up)

    fill_in 'Email', with: user.email
    click_button 'Send me reset password instructions'

    user.reset_password_sent_at =
      Time.zone.now - Devise.reset_password_within - 1.hour

    raw_reset_token, db_confirmation_token =
      Devise.token_generator.generate(User, :reset_password_token)
    user.update(reset_password_token: db_confirmation_token)

    visit edit_user_password_path(reset_password_token: raw_reset_token)

    expect(page).to have_content t('devise.passwords.token_expired')

    expect(current_path).to eq new_user_password_path
  end

  # Scenario: User takes too long to reset password
  #   Given I do not remember my password as a user
  #   When I complete the forms to reset password after time limit
  #   Then I see a helpful error message
  #   And I am redirected to the new_user_password_path
  scenario 'user takes too long to reset password' do
    user = create(:user, :signed_up)

    fill_in 'Email', with: user.email
    click_button 'Send me reset password instructions'

    raw_reset_token, db_confirmation_token =
      Devise.token_generator.generate(User, :reset_password_token)
    user.update(reset_password_token: db_confirmation_token)

    visit edit_user_password_path(reset_password_token: raw_reset_token)

    Timecop.travel(Devise.reset_password_within + 1.minute)

    fill_in 'New password', with: 'NewVal!dPassw0rd'
    fill_in 'Confirm your new password', with: 'NewVal!dPassw0rd'
    click_button 'Change my password'

    expect(page).to have_content t('devise.passwords.token_expired')
    expect(current_path).to eq new_user_password_path

    Timecop.return
  end

  # Scenario: Unconfirmed user account receives confirmation instructions
  #   Given my user account is unconfirmed
  #   When I complete the form on the password recovery page
  #   Then I receive confirmation instructions
  scenario 'unconfirmed user requests reset instructions', email: true do
    user = create(:user)
    user.update(confirmed_at: nil)

    visit root_path
    click_link t('upaya.headings.passwords.forgot')
    fill_in 'Email', with: user.email
    click_button 'Send me reset password instructions'

    expect(last_email.subject).
      to eq t('devise.mailer.confirmation_instructions.subject')
  end

  scenario 'passwords new view has a localized title' do
    expect(page).to have_title t('upaya.titles.passwords.forgot')
  end

  scenario 'passwords new view has a localized heading' do
    expect(page).to have_content t('upaya.headings.passwords.forgot')
  end

  # Scenario: User enters non-existent email address into password reset form
  #   Given I am not signed in
  #   When I enter a non-existent email address
  #   Then I see 'email sent'
  scenario 'user enters non-existent email address into password reset form' do
    fill_in 'user_email', with: 'ThisEmailAddressShall@NeverExist.com'
    click_button 'Send me reset password instructions'

    expect(page).to have_content t('devise.passwords.send_instructions')
    expect(page).not_to(have_content('not found'))
    expect(page).not_to(have_content('Please review the problems below:'))
  end

  # Scenario: Tech support user requests password reset
  #   Given I am not signed in
  #   When I enter my email address
  #   Then I see 'email sent' but do not receive recovery email.
  scenario 'tech user enters email address into password reset form' do
    reset_email
    user = create(:user, :signed_up, :tech_support)

    fill_in 'user_email', with: user.email
    click_button 'Send me reset password instructions'

    expect(page).to have_content t('devise.passwords.send_instructions')
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  # Scenario: Admin user requests password reset
  #   Given I am not signed in
  #   When I enter my email address
  #   Then I see 'email sent' but do not receive recovery email.
  scenario 'admin user enters email address into password reset form' do
    reset_email
    user = create(:user, :signed_up, :admin)

    fill_in 'user_email', with: user.email
    click_button 'Send me reset password instructions'

    expect(page).to have_content t('devise.passwords.send_instructions')
    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
