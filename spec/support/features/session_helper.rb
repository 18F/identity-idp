require 'omniauth_spec_helper'

module Features
  module SessionHelper
    VALID_PASSWORD = 'Val!dPassw0rd'.freeze

    def sign_up_with(email)
      visit new_user_registration_path
      fill_in 'Email', with: email
      click_button 'Sign up'
    end

    def signin(email, password)
      visit new_user_session_path
      fill_in 'Email', with: email
      fill_in 'Password', with: password
      click_button 'Log in'
    end

    def sign_up_with_and_set_password_for(email = nil, reset_session = false)
      email ||= Faker::Internet.email
      sign_up_with(email)
      user = User.find_by_email(email)
      Capybara.reset_session! if reset_session
      confirm_last_user
      fill_in 'user[password]', with: VALID_PASSWORD
      fill_in 'user[password_confirmation]', with: VALID_PASSWORD
      click_button 'Submit'
      user
    end

    def sign_in_user(user = create(:user))
      signin(user.email, user.password)
      user
    end

    def sign_in_with_warden(user)
      login_as(user, scope: :user, run_callbacks: false)
      allow(user).to receive(:need_two_factor_authentication?).and_return(false)
      visit dashboard_index_path
    end

    def sign_in_and_2fa_user(user = create_user('555-555-5556'))
      sign_in_with_warden(user)
      user
    end

    def create_user(mobile = '')
      create(:user, :signed_up, mobile: mobile)
    end

    def confirm_last_user
      @raw_confirmation_token, = Devise.token_generator.generate(User, :confirmation_token)

      User.last.update(
        confirmation_token: @raw_confirmation_token, confirmation_sent_at: Time.current)
      visit "/users/confirmation?confirmation_token=#{@raw_confirmation_token}"
    end

    def successful_account_creation_notice
      t('upaya.notices.account_created',
        date: (Time.current + 1.year).strftime('%B %d, %Y'))
    end
  end
end
