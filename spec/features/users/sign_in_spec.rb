require 'rails_helper'

include SessionTimeoutWarningHelper
include ActionView::Helpers::DateHelper

# Feature: Sign in
#   As a user
#   I want to sign in
#   So I can visit protected areas of the site
feature 'Sign in' do
  # Scenario: User cannot sign in if not registered
  #   Given I do not exist as a user
  #   When I sign in with valid credentials
  #   Then I see an invalid credentials message
  scenario 'user cannot sign in if not registered' do
    signin('test@example.com', 'Please123!')
    expect(page).to have_content t('devise.failure.not_found_in_database')
  end

  # Scenario: User cannot sign in with wrong email
  #   Given I exist as a user
  #   And I am not signed in
  #   When I sign in with a wrong email
  #   Then I see an invalid email message
  scenario 'user cannot sign in with wrong email' do
    user = create(:user)
    signin('invalid@email.com', user.password)
    expect(page).to have_content t('devise.failure.not_found_in_database')
  end

  scenario 'user cannot sign in with empty email', js: true do
    signin('', 'foo')

    expect(page).to have_content 'Please fill in all required fields'
  end

  scenario 'user cannot sign in with empty password', js: true do
    signin('test@example.com', '')

    expect(page).to have_content 'Please fill in all required fields'
  end

  # Scenario: User cannot sign in with wrong password
  #   Given I exist as a user
  #   And I am not signed in
  #   When I sign in with a wrong password
  #   Then I see an invalid password message
  scenario 'user cannot sign in with wrong password' do
    user = create(:user)
    signin(user.email, 'invalidpass')
    expect(page).to have_content t('devise.failure.invalid')
  end

  # Scenario: User is locked out from logging in after 3 failed attampts
  #   Given I exist as a user
  #   And I am not signed in
  #   When I sign in with a wrong password
  #   Then I see an invalid password message
  context 'user fails login 3 times' do
    before do
      password = '1Validpass!'
      @user = create(:user, password: password)
      signin(@user.email, 'invalidpass')
      signin(@user.email, 'invalidpass')
      signin(@user.email, 'invalidpass')
      @user.reload
    end

    it 'locks the user account after 3 failed sign in attempts' do
      expect(@user.locked_at).to be_present
    end

    it 'sends an email to user letting them know they are locked out', email: true do
      expect(last_email.subject).to eq 'Upaya Account Locked'
      expect(last_email.body).
        to have_content 'Your account will be unlocked in 20 minutes.'
    end

    it 'does not include any links in the account locked email' do
      expect(last_email.body).to_not have_selector 'a'
    end

    it 'treats failed attempt as invalid password during lockout period' do
      signin(@user.email, 'invalidpass')
      expect(page).to have_content t('devise.failure.invalid')
    end

    it 'keeps user locked out even with valid password during lockout period' do
      signin(@user.email, '1Validpass!')
      expect(current_path).to eq root_path
    end

    it 'allows the user back in after lockout period' do
      @user.update(locked_at: Time.zone.now - (Devise.unlock_in + 1))
      signin(@user.email, '1Validpass!')

      expect(current_path).to eq users_otp_path
    end
  end

  scenario 'user session expires in amount of time specified by Devise config' do
    sign_in_and_2fa_user
    visit edit_user_registration_path
    expect(current_path).to eq edit_user_registration_path

    Timecop.travel(Devise.timeout_in + 1.minute)
    visit edit_user_registration_path

    expect(current_path).to eq root_path

    Timecop.return
  end

  context 'session approaches timeout', js: true do
    before :each do
      allow(Rails.application.config).to receive(:session_check_frequency).and_return(1)
      allow(Rails.application.config).to receive(:session_check_delay).and_return(1)
      allow(Rails.application.config).to receive(:session_timeout_warning_seconds).
        and_return(Devise.timeout_in)
    end

    scenario 'user sees warning before session times out' do
      def warning_content
        t('upaya.session_timeout_warning',
          time_left_in_session: time_left_in_session,
          continue_text: t('upaya.forms.buttons.continue_browsing'))
      end

      sign_in_and_2fa_user
      visit root_path

      expect(page).to have_css('#session-timeout-msg', text: warning_content)

      find_link('Continue Browsing').trigger('click')

      expect(current_path).to eq dashboard_index_path
    end
  end

  context 'signed out' do
    it 'does not display session timeout JS', js: true do
      allow(Rails.application.config).to receive(:session_check_frequency).and_return(1)
      allow(Rails.application.config).to receive(:session_check_delay).and_return(1)
      allow(Rails.application.config).to receive(:session_timeout_warning_seconds).
        and_return(Devise.timeout_in)

      visit root_path
      sleep 2

      expect(page).to_not have_css('.alert')
    end

    it 'does not render session_timeout/warning partial' do
      visit root_path

      expect(page).to_not have_css('#session-timeout-msg', visible: false)
    end
  end

  context 'signing back in after session timeout length' do
    before do
      ActionController::Base.allow_forgery_protection = true
    end

    after do
      ActionController::Base.allow_forgery_protection = false
      Timecop.return
    end

    it 'successfully signs in the user' do
      user = sign_in_user
      click_link(t('upaya.links.sign_out'))

      Timecop.travel(Devise.timeout_in + 1.minute)

      fill_in 'Email', with: user.email
      fill_in 'Password', with: user.password
      click_button 'Log in'

      expect(page).to_not have_content t('upaya.errors.invalid_authenticity_token')
      expect(current_path).to eq users_otp_path
    end
  end

  context 'signed in, session times out, sign back in', js: true do
    it 'prompts to enter OTP' do
      allow(Rails.application.config).to receive(:session_check_frequency).and_return(0.01)
      allow(Rails.application.config).to receive(:session_check_delay).and_return(0.01)
      allow(Devise).to receive(:timeout_in).and_return(1.second)

      user = sign_in_and_2fa_user
      Timecop.travel(1.minute)
      visit '/'

      fill_in 'Email', with: user.email
      fill_in 'Password', with: user.password
      click_button 'Log in'

      expect(current_path).to eq user_two_factor_authentication_path
      Timecop.return
    end
  end

  describe 'session timeout configuration' do
    it 'uses delay and warning settings whose sum is a multiple of 60' do
      expect((start + warning) % 60).to eq 0
    end

    it 'uses frequency and warning settings whose sum is a multiple of 60' do
      expect((frequency + warning) % 60).to eq 0
    end
  end
end
