require 'rails_helper'

feature 'Password Recovery' do
  def reset_password_and_sign_back_in(user, password = 'a really long password')
    fill_in t('forms.passwords.edit.labels.password'), with: password
    click_button t('forms.passwords.edit.buttons.submit')
    fill_in_credentials_and_submit(user.email, password)
  end

  context 'user can reset their password via email', email: true do
    before do
      user = create(:user, :signed_up)

      visit root_path
      click_link t('links.passwords.forgot')
      fill_in 'Email', with: user.email
      click_button t('forms.buttons.continue')
    end

    it 'uses a relevant email subject' do
      expect(last_email.subject).to eq t('devise.mailer.reset_password_instructions.' \
                                         'subject')
    end

    it 'includes a link to customer service in the email' do
      expect(last_email.html_part.body).to include contact_url
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
      expect(last_email.html_part.body).to have_content(
        t(
          'mailer.reset_password.footer',
          expires: (Devise.reset_password_within / 3600)
        )
      )
    end
  end

  context 'user with only email confirmation resets password', email: true do
    before do
      user = create(:user, :unconfirmed)
      confirm_last_user
      reset_email
      visit new_user_password_path
      fill_in 'Email', with: user.email
      click_button t('forms.buttons.continue')
      open_last_email
      click_email_link_matching(/confirmation_token/)
    end

    it 'shows the password form' do
      expect(page).to have_content t('forms.confirmation.show_hdr')
    end
  end

  context 'user with email confirmation resends confirmation', email: true do
    before do
      user = create(:user, :unconfirmed)
      confirm_last_user
      reset_email
      visit sign_up_email_resend_path
      fill_in 'Email', with: user.email
      click_button t('forms.buttons.resend_confirmation')
      open_last_email
      click_email_link_matching(/confirmation_token/)
    end

    it 'shows the password form' do
      expect(page).to have_content t('forms.confirmation.show_hdr')
    end
  end

  context 'user with password confirmation resets password', email: true do
    before do
      @user = create(:user)
      visit new_user_password_path
      fill_in 'Email', with: @user.email
      click_button t('forms.buttons.continue')
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
      click_button t('forms.buttons.continue')
      visit edit_user_password_path(reset_password_token: 'invalid_token')
    end

    it 'redirects to new user password form' do
      expect(current_path).to eq new_user_password_path
    end

    it 'displays a flash error message' do
      expect(page).to have_content t('devise.passwords.invalid_token')
    end
  end

  context 'user with 2FA confirmation resets password', email: true do
    before do
      @user = create(:user, :signed_up)
      visit new_user_password_path
      fill_in 'Email', with: @user.email
      click_button t('forms.buttons.continue')
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

  scenario 'user submits email address with invalid format' do
    invalid_addresses = [
      'user@domain-without-suffix',
      'Buy Medz 0nl!ne http://pharma342.onlinestore.com'
    ]
    allow(ValidateEmail).to receive(:mx_valid?).and_return(false)

    visit new_user_password_path

    invalid_addresses.each do |email|
      fill_in 'Email', with: email
      click_button t('forms.buttons.continue')

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
      click_button t('forms.buttons.continue')

      expect(page).to have_content t('valid_email.validations.email.invalid')
    end
  end

  scenario 'user submits blank email address' do
    visit new_user_password_path
    click_button t('forms.buttons.continue')

    expect(page).to have_content t('valid_email.validations.email.invalid')
  end

  scenario 'user is unable to determine if account exists' do
    visit new_user_password_path
    fill_in 'Email', with: 'no_account_exists@gmail.com'
    click_button t('forms.buttons.continue')

    expect(page).to have_content(t('notices.password_reset'))
  end

  context 'user can reset their password' do
    before do
      @user = create(:user, :signed_up)

      visit new_user_password_path
      fill_in 'Email', with: @user.email
      click_button t('forms.buttons.continue')

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
        fill_in t('forms.passwords.edit.labels.password'), with: 'NewVal!dPassw0rd'

        click_button t('forms.passwords.edit.buttons.submit')

        expect(page).to have_content(t('devise.passwords.updated_not_active'))

        expect(last_email.subject).to eq t('devise.mailer.password_updated.subject')

        visit profile_path
        expect(current_path).to eq new_user_session_path
      end
    end

    context 'when password form values are invalid' do
      it 'does not allow the user to submit until password score is good', js: true do
        fill_in t('forms.passwords.edit.labels.password'), with: 'invalid'
        expect(page).not_to have_button(t('forms.passwords.edit.buttons.submit'))

        fill_in t('forms.passwords.edit.labels.password'), with: 'password@132!'
        expect(page).not_to have_button(t('forms.passwords.edit.buttons.submit'))

        fill_in t('forms.passwords.edit.labels.password'), with: 'a unique and exciting zxjsahfas'
        expect(page).to have_button(t('forms.passwords.edit.buttons.submit'))
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

      it "does not update the user's password when password is invalid" do
        fill_in 'New password', with: '1234'
        click_button t('forms.passwords.edit.buttons.submit')

        signin(@user.email, '1234')
        expect(current_path).to eq new_user_session_path
      end

      it 'allows multiple attempts with invalid password' do
        fill_in 'New password', with: '1234'
        click_button t('forms.passwords.edit.buttons.submit')

        expect(page).to have_content 'is too short'

        fill_in 'New password', with: '5678'
        click_button t('forms.passwords.edit.buttons.submit')

        expect(page).to have_content 'is too short'
      end
    end
  end

  scenario 'LOA3 user resets password and reactivates profile with recovery code', email: true do
    user = create(:user, :signed_up)

    recovery_code = recovery_code_from_pii(user, ssn: '1234', dob: '1920-01-01')
    password = 'some really awesome new password'

    visit new_user_password_path
    fill_in 'Email', with: user.email
    click_button t('forms.buttons.continue')
    open_last_email
    click_email_link_matching(/reset_password_token/)

    reset_password_and_sign_back_in(user, password)
    click_submit_default
    enter_correct_otp_code_for_user(user)

    expect(page).to have_content t('profile.index.reactivation.instructions')
    click_link t('profile.index.reactivation.reactivate_button')

    fill_in 'Password', with: password
    fill_in 'Recovery code', with: recovery_code
    click_button t('forms.reactivate_profile.submit')

    expect(page).to have_content t('idv.messages.recovery_code')
  end

  scenario 'user takes too long to click the reset password link' do
    user = create(:user, :signed_up)

    visit new_user_password_path
    fill_in 'Email', with: user.email
    click_button t('forms.buttons.continue')

    user.reset_password_sent_at =
      Time.zone.now - Devise.reset_password_within - 1.hour

    raw_reset_token, db_confirmation_token =
      Devise.token_generator.generate(User, :reset_password_token)
    user.update(reset_password_token: db_confirmation_token)

    visit edit_user_password_path(reset_password_token: raw_reset_token)

    expect(page).to have_content t('devise.passwords.token_expired')

    expect(current_path).to eq new_user_password_path
  end

  scenario 'unconfirmed user requests reset instructions', email: true do
    user = create(:user, :unconfirmed)

    visit new_user_password_path
    fill_in 'Email', with: user.email
    click_button t('forms.buttons.continue')

    expect(last_email.subject).
      to eq t('devise.mailer.confirmation_instructions.subject')
  end

  scenario 'user enters non-existent email address into password reset form' do
    visit new_user_password_path
    fill_in 'user_email', with: 'ThisEmailAddressShall@NeverExist.com'
    click_button t('forms.buttons.continue')

    expect(page).to have_content t('notices.password_reset')
    expect(page).not_to(have_content('not found'))
    expect(page).not_to(have_content(t('simple_form.error_notification.default_message')))
  end

  scenario 'tech user enters email address into password reset form' do
    reset_email
    user = create(:user, :signed_up, :tech_support)

    visit new_user_password_path
    fill_in 'user_email', with: user.email
    click_button t('forms.buttons.continue')

    expect(page).to have_content t('notices.password_reset')
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  scenario 'admin user enters email address into password reset form' do
    reset_email
    user = create(:user, :signed_up, :admin)

    visit new_user_password_path
    fill_in 'user_email', with: user.email
    click_button t('forms.buttons.continue')

    expect(page).to have_content t('notices.password_reset')
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  def recovery_code_from_pii(user, pii)
    profile = create(:profile, :active, :verified, user: user)
    pii_attrs = Pii::Attributes.new_from_hash(pii)
    user_access_key = user.unlock_user_access_key(user.password)
    recovery_code = profile.encrypt_pii(user_access_key, pii_attrs)
    profile.save!

    recovery_code
  end
end
