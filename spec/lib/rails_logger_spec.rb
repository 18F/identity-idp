require 'rails_helper'

describe 'Rails.logger', type: :feature do
  context 'when attempting to authenticate' do
    let(:user) { create(:user, :signed_up) }

    before do
      visit new_user_session_path
      fill_in 'Email', with: user.email
      fill_in 'Password', with: user.password
    end

    it 'logs succesful attempt' do
      expect(Rails.logger).to receive(:info).with('[Authentication Attempt]')
      expect(Rails.logger).to receive(:info).with("[#{user.uuid}] [Authentication Successful]")
      sign_in_user(user)
    end

    it 'logs failed attempt' do
      expect(Rails.logger).to receive(:info).with('[Authentication Attempt]')
      expect(Rails.logger).to receive(:info).with("[#{user.uuid}] [Authentication Failed]")
      signin(user.email, 'Wr0ngPassword!')
    end
  end

  context 'when creating an account' do
    let(:new_email) { Faker::Internet.email }
    before do
      sign_up_with(new_email)
      confirm_last_user

      fill_in 'user[password]', with: 'ValidPassw0rd!'
      fill_in 'user[password_confirmation]', with: 'ValidPassw0rd!'
    end

    it 'logs [Password Created]' do
      user = User.find_by_email(new_email)
      expect(Rails.logger).to receive(:info).with("[#{user.uuid}] [Authentication Successful]")
      expect(Rails.logger).to receive(:info).with("[#{user.uuid}] [Password Created]")
      click_button 'Submit'
    end
  end

  context 'when changing password' do
    let(:user) { create(:user, :signed_up) }

    before do
      sign_in_and_2fa_user(user)
      user_password = 'ValidPassw0rd!'
      visit edit_user_registration_path

      fill_in 'update_user_profile_form_current_password', with: user.password
      fill_in 'update_user_profile_form_password', with: user_password
      fill_in 'update_user_profile_form_password_confirmation', with: user_password
    end

    it 'logs [Password Changed]' do
      expect(Rails.logger).to receive(:info).with("[#{user.uuid}] [Password Changed]")
      click_button 'Update'
    end
  end

  context 'when an account is locked out' do
    let(:user) { create(:user, :signed_up) }

    before do
      (Devise.maximum_attempts - 1).times do
        visit new_user_session_path
        fill_in 'Email', with: user.email
        fill_in 'Password', with: 'i haz no idear'
        click_button 'Log in'
      end
      visit new_user_session_path
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'i haz no idear'
    end

    it 'logs the attempt and locked out events' do
      expect(Rails.logger).to receive(:info).with('[Authentication Attempt]')
      expect(Rails.logger).to receive(:info).with("[#{user.uuid}] [Authentication Failed]")
      expect(Rails.logger).to receive(:info).with("[#{user.uuid}] [Account Locked]")
      click_button 'Log in'
    end
  end

  context 'when a user resets password' do
    let(:user) { create(:user, :signed_up) }

    before do
      visit new_user_password_path

      fill_in 'Email', with: user.email
      click_button 'Send me reset password instructions'

      raw_reset_token, db_confirmation_token =
        Devise.token_generator.generate(User, :reset_password_token)
      user.update(reset_password_token: db_confirmation_token)

      visit edit_user_password_path(reset_password_token: raw_reset_token)
    end

    it 'logs the events' do
      fill_in 'New password', with: 'NewVal!dPassw0rd'
      fill_in 'Confirm your new password', with: 'NewVal!dPassw0rd'

      expect(Rails.logger).to receive(:info).with("[#{user.uuid}] [Password Changed]")
      click_button 'Change my password'
    end
  end
end
