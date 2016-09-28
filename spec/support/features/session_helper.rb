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
      click_button t('links.sign_in')
    end

    def sign_up_and_set_password
      user = create(:user, :unconfirmed)
      confirm_last_user
      fill_in 'password_form_password', with: VALID_PASSWORD
      click_button t('forms.buttons.submit.default')
      user
    end

    def sign_in_user(user = create(:user))
      signin(user.email, user.password)
      user
    end

    def sign_in_before_2fa(user = create(:user))
      login_as(user, scope: :user, run_callbacks: false)

      if user.phone.present?
        Warden.on_next_request do |proxy|
          session = proxy.env['rack.session']
          session['warden.user.user.session'] = {}
          session['warden.user.user.session']['need_two_factor_authentication'] = true
        end
      end

      visit profile_path
      user
    end

    def sign_in_with_warden(user)
      login_as(user, scope: :user, run_callbacks: false)
      allow(user).to receive(:need_two_factor_authentication?).and_return(false)
      Warden.on_next_request do |proxy|
        session = proxy.env['rack.session']
        session['warden.user.user.session'] = { authn_at: Time.zone.now }
      end
      visit profile_path
    end

    def sign_in_and_2fa_user(user = create(:user, :signed_up, phone: '+1 (555) 555-5556'))
      sign_in_with_warden(user)
      user
    end

    def confirm_last_user
      @raw_confirmation_token, = Devise.token_generator.generate(User, :confirmation_token)

      User.last.update(
        confirmation_token: @raw_confirmation_token, confirmation_sent_at: Time.current
      )
      visit "/users/confirmation?confirmation_token=#{@raw_confirmation_token}"
    end

    def sign_up_and_2fa
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      user = sign_up_and_set_password
      fill_in 'Phone', with: '202-555-1212'
      # Select SMS delivery
      click_button t('forms.buttons.send_passcode')
      # Enter 2FA code
      click_button t('forms.buttons.submit.default')
      # Acknowledge recovery code
      click_button t('forms.buttons.submit.continue')
      user
    end
  end
end
