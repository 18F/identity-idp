require 'rails_helper'

feature 'Sign Up', devise: true do
  scenario 'visitor can sign up with valid email address' do
    email = 'test@example.com'
    sign_up_with(email)

    expect(page).to have_content t('notices.signed_up_but_unconfirmed.first_paragraph_start')
    expect(page).to have_content t('notices.signed_up_but_unconfirmed.first_paragraph_end')
    expect(page).
      to have_content t('notices.signed_up_but_unconfirmed.no_email_sent_explanation_start')
    expect(page).to have_content email
    expect(page).to have_link(t('links.resend'), href: new_user_confirmation_path)
  end

  context 'visitor can sign up and confirm a valid phone for OTP' do
    before do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      allow(SmsOtpSenderJob).to receive(:perform_later)
      @user = sign_in_before_2fa
      fill_in 'Phone', with: '555-555-5555'
      click_button t('forms.buttons.send_passcode')

      expect(SmsOtpSenderJob).to have_received(:perform_later).with(
        code: @user.reload.direct_otp,
        phone: '+1 (555) 555-5555',
        otp_created_at: @user.direct_otp_sent_at.to_s
      )
    end

    it 'updates phone_confirmed_at and redirects to acknowledge recovery code' do
      click_button t('forms.buttons.submit.default')

      expect(@user.reload.phone_confirmed_at).to be_present
      expect(current_path).to eq settings_recovery_code_path

      click_button t('forms.buttons.acknowledge_recovery_code')

      expect(current_path).to eq profile_path
    end

    it 'allows user to resend confirmation code' do
      click_link t('links.two_factor_authentication.resend_code')

      expect(current_path).to eq login_two_factor_path(delivery_method: 'sms')
    end

    it 'does not enable 2FA until correct OTP is entered' do
      fill_in 'code', with: '12345678'
      click_button t('forms.buttons.submit.default')

      expect(@user.reload.two_factor_enabled?).to be false
    end

    it 'provides user with link to type in a phone number so they are not locked out' do
      click_link 'Try again'
      expect(current_path).to eq phone_setup_path
    end

    it 'informs the user that the OTP code is sent to the phone' do
      expect(page).to have_content(t('instructions.2fa.confirm_code', number: '+1 (555) 555-5555'))
    end

    it 'allows user to enter new number if they Sign Out before confirming' do
      click_link(t('links.sign_out'))
      signin(@user.reload.email, @user.password)
      expect(current_path).to eq phone_setup_path
    end
  end

  context "visitor tries to sign up with another user's phone for OTP" do
    before do
      @existing_user = create(:user, :signed_up)
      @user = sign_in_before_2fa
      fill_in 'Phone', with: @existing_user.phone
      click_button t('forms.buttons.send_passcode')
    end

    it 'pretends the phone is valid and prompts to confirm the number' do
      expect(current_path).to eq login_two_factor_path(delivery_method: 'sms')
      expect(page).to have_content(t('instructions.2fa.confirm_code', number: '+1 (202) 555-1212'))
    end

    it 'does not confirm the new number with an invalid code' do
      fill_in 'code', with: 'foobar'
      click_button t('forms.buttons.submit.default')

      expect(@user.reload.phone_confirmed_at).to be_nil
      expect(page).to have_content t('devise.two_factor_authentication.invalid_otp')
      expect(current_path).to eq login_two_factor_path(delivery_method: 'sms')
    end
  end

  scenario 'visitor is redirected back to password form when password is blank' do
    create(:user, :unconfirmed)
    confirm_last_user
    fill_in 'password_form_password', with: ''
    click_button t('forms.buttons.submit.default')

    expect(page).to have_content t('errors.messages.blank')
    expect(current_url).to eq confirm_url
  end

  context 'password field is blank when JS is on', js: true do
    before do
      create(:user, :unconfirmed)
      confirm_last_user
    end

    it 'shows error message when password is blank' do
      fill_in 'password_form_password', with: ''
      click_button t('forms.buttons.submit.default')

      expect(page).to have_content 'Please fill in this field.'
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
      expect(page).to have_content 'Great!'
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

    expect(page).to have_css('input.password[type="password"]')

    find('#pw-toggle-0', visible: false).trigger('click')

    expect(page).to_not have_css('input.password[type="password"]')
    expect(page).to have_css('input.password[type="text"]')
  end

  context 'password is invalid' do
    scenario 'visitor is redirected back to password form' do
      create(:user, :unconfirmed)
      confirm_last_user
      fill_in 'password_form_password', with: 'Q!2e'

      click_button t('forms.buttons.submit.default')

      expect(page).to have_content('characters')
      expect(current_url).to eq confirm_url
    end

    scenario 'visitor gets password help message' do
      allow(Figaro.env).to receive(:password_strength_enabled).and_return('true')

      create(:user, :unconfirmed)
      confirm_last_user
      fill_in 'password_form_password', with: 'password'

      click_button t('forms.buttons.submit.default')

      expect(page).to have_content('not strong enough')
    end
  end

  context 'confirmed user is signed in and tries to confirm again' do
    it 'redirects the user to the profile' do
      sign_up_and_2fa

      visit user_confirmation_url(confirmation_token: @raw_confirmation_token)

      expect(current_url).to eq profile_url
    end
  end

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

  scenario 'visitor signs up but confirms with an invalid token' do
    create(:user, :unconfirmed)
    visit '/users/confirmation?confirmation_token=invalid_token'

    expect(page).to have_content t('errors.messages.confirmation_invalid_token')
    expect(current_path).to eq user_confirmation_path
  end

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

  context 'user signs up twice without confirming email' do
    it 'sends the user the confirmation instructions email again' do
      email = 'test@example.com'

      expect { sign_up_with(email) }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(last_email.html_part.body).to have_content(
        t('devise.mailer.confirmation_instructions.subject')
      )

      expect { sign_up_with(email) }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(last_email.html_part.body).to have_content(
        t('devise.mailer.confirmation_instructions.subject')
      )
    end
  end

  context 'user signs up and requests confirmation email again' do
    it 'sends the confirmation email again' do
      sign_up_with('test@example.com')
      click_on t('links.resend')
      fill_in :user_email, with: 'test@example.com'

      expect { click_on t('forms.buttons.resend_confirmation') }.
        to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(last_email.html_part.body).to have_content(
        t('devise.mailer.confirmation_instructions.subject')
      )
    end
  end

  context 'user signs up and sets password, tries to sign up again' do
    it 'sends email saying someone tried to sign up with their email address' do
      user = create(:user)

      expect { sign_up_with(user.email) }.
        to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(last_email.html_part.body).to have_content(
        t('user_mailer.signup_with_your_email.intro', app: APP_NAME)
      )
    end
  end
end
