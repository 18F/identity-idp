require 'rails_helper'
require 'axe/rspec'

feature 'Accessibility on pages that require authentication', :js do
  scenario 'user registration page' do
    email = 'test@example.com'
    sign_up_with(email)

    expect(current_path).to eq(sign_up_verify_email_path)
    expect(page).to be_accessible
  end

  describe 'user confirmation page' do
    scenario 'valid confirmation token' do
      create(:user, :unconfirmed)
      confirm_last_user

      expect(current_path).to eq(sign_up_create_email_confirmation_path)
      expect(page).to be_accessible
    end

    scenario 'invalid confirmation token' do
      visit sign_up_create_email_confirmation_path(confirmation_token: '123456')

      expect(current_path).to eq(sign_up_email_resend_path)
      expect(page).to be_accessible
    end
  end

  describe '2FA pages' do
    scenario 'phone setup page' do
      sign_up_and_set_password

      expect(current_path).to eq(phone_setup_path)
      expect(page).to be_accessible
    end

    scenario 'two factor auth page' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)

      expect(current_path).to eq(user_two_factor_authentication_path)
      expect(page).to be_accessible
    end

    describe 'SMS' do
      scenario 'enter 2fa phone OTP code page' do
        user = create(:user, phone: '+1 (202) 555-1212')
        sign_in_before_2fa(user)
        visit login_two_factor_path(delivery_method: 'sms')

        expect(current_path).to eq login_two_factor_path(delivery_method: 'sms')
        expect(page).to be_accessible
      end
    end

    describe 'Voice' do
      scenario 'enter 2fa phone OTP code page' do
        user = create(:user, phone: '+1 (202) 555-1212')
        sign_in_before_2fa(user)
        visit login_two_factor_path(delivery_method: 'voice')

        expect(current_path).to eq login_two_factor_path(delivery_method: 'voice')
        expect(page).to be_accessible
      end
    end
  end

  scenario 'recovery code page' do
    sign_in_and_2fa_user
    visit manage_recovery_code_path

    expect(page).to be_accessible
  end

  scenario 'profile page' do
    sign_in_and_2fa_user

    visit profile_path

    expect(page).to be_accessible
  end

  scenario 'edit email page' do
    sign_in_and_2fa_user

    visit manage_email_path

    expect(page).to be_accessible
  end

  scenario 'edit password page' do
    sign_in_and_2fa_user

    visit manage_password_path

    expect(page).to be_accessible
  end

  scenario 'edit phone page' do
    sign_in_and_2fa_user

    visit manage_phone_path

    expect(page).to be_accessible
  end

  scenario 'generate new recovery code page' do
    sign_in_and_2fa_user

    visit manage_recovery_code_path

    expect(page).to be_accessible
  end

  scenario 'start set up of authenticator app page' do
    sign_in_and_2fa_user

    visit '/authenticator_start'

    expect(page).to be_accessible
  end

  scenario 'set up authenticator app page' do
    sign_in_and_2fa_user

    visit '/authenticator_setup'

    expect(page).to be_accessible
  end
end
