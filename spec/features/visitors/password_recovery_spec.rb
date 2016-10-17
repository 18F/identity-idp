require 'rails_helper'

# Feature: Password Recovery
#   As a user
#   I want to recover my password
#   So I can regain access to protected areas of the site
feature 'Password Recovery' do
  def reset_password_and_sign_back_in(user)
    password = 'a really long password'
    fill_in 'New password', with: password
    click_button t('forms.passwords.edit.buttons.submit')
    fill_in 'Email', with: user.email
    fill_in 'user_password', with: password
    click_button t('links.sign_in')
  end

  # Scenario: User can request a password reset link be sent to them
  #   Given I do not remember my password as a user
  #   When I complete the form on the password recovery page
  #   Then I receive an email
  context 'user can reset their password via email', email: true do
    before do
      user = create(:user, :signed_up)

      visit root_path
      click_link t('headings.passwords.forgot')
      fill_in 'Email', with: user.email
      click_button t('forms.buttons.reset_password')
    end

    it 'uses a relevant email subject' do
      expect(last_email.subject).to eq t('devise.mailer.reset_password_instructions.' \
                                         'subject')
    end

    it 'includes a link to customer service in the email' do
      expect(last_email.html_part.body).
        to include Figaro.env.support_url
    end

    it 'displays a localized notice' do
      expect(page).to have_content t('notices.password_reset')
    end

    it 'includes a link to reset the password in the email' do
      open_last_email
      click_email_link_matching(/reset_password_token/)

      expect(current_path).to eq edit_user_password_path
    end

    it 'specifies how long the user has to reset the password based on Devise settings' do
      expect(last_email.html_part.body).
        to have_content "expires in #{Devise.reset_password_within / 3600} hours"
    end
  end

  # Scenario: User that has only confirmed their email can reset their password
  #   Given I have not created my password yet
  #   And I click the Forgot password? link and enter my email
  #   Then I receive the confirmation email again
  #   And when I click the link in the confirmation email
  #   Then I can set my password
  context 'user with only email confirmation resets password', email: true do
    before do
      user = create(:user, :unconfirmed)
      confirm_last_user
      reset_email
      visit new_user_password_path
      fill_in 'Email', with: user.email
      click_button t('forms.buttons.reset_password')
      open_last_email
      click_email_link_matching(/confirmation_token/)
    end

    it 'shows the password form' do
      expect(page).to have_content t('forms.confirmation.show_hdr')
    end
  end

  # Scenario: User that has only confirmed their email can reset their password
  #   Given I have not created my password yet
  #   And I go to new user confirmation page and enter my email
  #   When I click the link in the confirmation email
  #   Then I can set a new password
  context 'user with email confirmation resends confirmation', email: true do
    before do
      user = create(:user, :unconfirmed)
      confirm_last_user
      reset_email
      visit new_user_confirmation_path
      fill_in 'Email', with: user.email
      click_button t('forms.buttons.resend_confirmation')
      open_last_email
      click_email_link_matching(/confirmation_token/)
    end

    it 'shows the password form' do
      expect(page).to have_content t('forms.confirmation.show_hdr')
    end
  end

  # Scenario: User that has only confirmed password can reset their password
  #   Given I have not set up 2FA yet
  #   And I click the Forgot password? link and enter my email
  #   When I click the link in the email
  #   Then I can set a new password
  context 'user with password confirmation resets password', email: true do
    before do
      @user = create(:user)
      visit new_user_password_path
      fill_in 'Email', with: @user.email
      click_button t('forms.buttons.reset_password')
      open_last_email
      click_email_link_matching(/reset_password_token/)
    end

    it 'keeps user signed out after they successfully reset their password' do
      fill_in 'New password', with: 'NewVal!dPassw0rd'
      click_button t('forms.passwords.edit.buttons.submit')

      expect(current_path).to eq new_user_session_path
    end

    it 'prompts user to set up their 2FA options after signing back in' do
      reset_password_and_sign_back_in(@user)

      expect(current_path).to eq phone_setup_path
    end
  end

  context 'user with invalid token cannot reset password', email: true do
    before do
      user = create(:user)
      visit new_user_password_path
      fill_in 'Email', with: user.email
      click_button t('forms.buttons.reset_password')
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
      @user = create(:user, :signed_up)
      visit new_user_password_path
      fill_in 'Email', with: @user.email
      click_button t('forms.buttons.reset_password')
      open_last_email
      click_email_link_matching(/reset_password_token/)
    end

    it 'redirects user to profile after signing back in' do
      reset_password_and_sign_back_in(@user)
      click_button t('forms.buttons.submit.default')
      fill_in 'code', with: @user.reload.direct_otp
      click_button t('forms.buttons.submit.default')

      expect(current_path).to eq profile_path
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

    visit new_user_password_path

    invalid_addresses.each do |email|
      fill_in 'Email', with: email
      click_button t('forms.buttons.reset_password')

      expect(page).to have_content t('valid_email.validations.email.invalid')
    end
  end

  scenario 'user submits email address with invalid domain name' do
    invalid_addresses = [
      'foo@bar.com',
      'foo@example.com'
    ]
    allow(ValidateEmail).to receive(:mx_valid?).and_return(false)

    visit new_user_password_path

    invalid_addresses.each do |email|
      fill_in 'Email', with: email
      click_button t('forms.buttons.reset_password')

      expect(page).to have_content t('valid_email.validations.email.invalid')
    end
  end

  scenario 'user submits blank email address' do
    visit new_user_password_path
    click_button t('forms.buttons.reset_password')

    expect(page).to have_content t('valid_email.validations.email.invalid')
  end

  scenario 'user submits blank email address and has JS turned on', js: true do
    visit new_user_password_path
    click_button t('forms.buttons.reset_password')

    expect(page).to have_content 'Please fill in this field.'
  end

  # Scenario: User is unable to determine if someone else's account exists
  #   Given I want to find out if an account exists
  #   When I complete the form on the password recovery page
  #   Then I still don't know if an account exists
  scenario 'user is unable to determine if account exists' do
    visit new_user_password_path
    fill_in 'Email', with: 'no_account_exists@gmail.com'
    click_button t('forms.buttons.reset_password')

    expect(page).to have_content(t('devise.passwords.send_instructions'))
  end

  # Scenario: User can reset their password
  #   Given I do not remember my password as a user
  #   When I complete the form on the password recovery page
  #   Then I receive an email
  context 'user can reset their password' do
    before do
      @user = create(:user, :signed_up)

      visit new_user_password_path
      fill_in 'Email', with: @user.email
      click_button t('forms.buttons.reset_password')

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

        click_button t('forms.passwords.edit.buttons.submit')

        expect(page).to have_content(t('devise.passwords.updated_not_active'))

        expect(last_email.subject).to eq t('devise.mailer.password_updated.subject')

        visit profile_path
        expect(current_path).to eq new_user_session_path
      end
    end

    it 'displays error when password fields are empty & JS is on', js: true do
      click_button t('forms.passwords.edit.buttons.submit')

      expect(page).to have_content 'Please fill in this field.'
    end

    it 'displays field validation error when password fields are empty' do
      click_button t('forms.passwords.edit.buttons.submit')

      expect(page).to have_content t('errors.messages.blank')
    end

    it 'displays field validation error when password field is too short' do
      fill_in 'New password', with: '1234'
      click_button t('forms.passwords.edit.buttons.submit')

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

    visit new_user_password_path
    fill_in 'Email', with: user.email
    click_button t('forms.buttons.reset_password')

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

    visit new_user_password_path
    fill_in 'Email', with: user.email
    click_button t('forms.buttons.reset_password')

    raw_reset_token, db_confirmation_token =
      Devise.token_generator.generate(User, :reset_password_token)
    user.update(reset_password_token: db_confirmation_token)

    visit edit_user_password_path(reset_password_token: raw_reset_token)

    Timecop.travel(Devise.reset_password_within + 1.minute)

    fill_in 'New password', with: 'NewVal!dPassw0rd'
    click_button t('forms.passwords.edit.buttons.submit')

    expect(page).to have_content t('devise.passwords.token_expired')
    expect(current_path).to eq new_user_password_path

    Timecop.return
  end

  # Scenario: Unconfirmed user account receives confirmation instructions
  #   Given my user account is unconfirmed
  #   When I complete the form on the password recovery page
  #   Then I receive confirmation instructions
  scenario 'unconfirmed user requests reset instructions', email: true do
    user = create(:user, :unconfirmed)

    visit new_user_password_path
    fill_in 'Email', with: user.email
    click_button t('forms.buttons.reset_password')

    expect(last_email.subject).
      to eq t('devise.mailer.confirmation_instructions.subject')
  end

  # Scenario: User enters non-existent email address into password reset form
  #   Given I am not signed in
  #   When I enter a non-existent email address
  #   Then I see 'email sent'
  scenario 'user enters non-existent email address into password reset form' do
    visit new_user_password_path
    fill_in 'user_email', with: 'ThisEmailAddressShall@NeverExist.com'
    click_button t('forms.buttons.reset_password')

    expect(page).to have_content t('devise.passwords.send_instructions')
    expect(page).not_to(have_content('not found'))
    expect(page).not_to(have_content(t('simple_form.error_notification.default_message')))
  end

  # Scenario: Tech support user requests password reset
  #   Given I am not signed in
  #   When I enter my email address
  #   Then I see 'email sent' but do not receive recovery email.
  scenario 'tech user enters email address into password reset form' do
    reset_email
    user = create(:user, :signed_up, :tech_support)

    visit new_user_password_path
    fill_in 'user_email', with: user.email
    click_button t('forms.buttons.reset_password')

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

    visit new_user_password_path
    fill_in 'user_email', with: user.email
    click_button t('forms.buttons.reset_password')

    expect(page).to have_content t('devise.passwords.send_instructions')
    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
