require 'rails_helper'

feature 'SAML Authorization Confirmation' do
  include SamlAuthHelper

  before do
    allow(Identity::Hostdata.settings).to receive(:otp_delivery_blocklist_maxretry).
      and_return('9999')
  end

  context 'authenticated user signs in to new sp' do
    def create_user_and_remember_device
      user = user_with_2fa

      sign_in_user(user)
      check :remember_device
      fill_in_code_with_last_phone_otp
      click_submit_default
      visit saml_authn_request
      click_agree_and_continue
      visit sign_out_url

      user
    end

    let(:user1) { create_user_and_remember_device }
    let(:user2) { create_user_and_remember_device }
    let(:saml_authn_request) { auth_request.create(saml_settings) }

    before do
      # Cycle user2 first so user1's remember device will stick
      user2
      user1
    end

    it 'it confirms the user wants to continue to the SP after signing in again' do
      sign_in_user(user1)

      visit saml_authn_request

      expect(current_url).to match(user_authorization_confirmation_path)
      continue_as(user1.email)

      expect(current_url).to eq(saml_authn_request)
    end

    it 'it allows the user to switch accounts prior to continuing to the SP' do
      sign_in_user(user1)

      visit saml_authn_request
      expect(current_url).to match(user_authorization_confirmation_path)
      continue_as(user2.email, user2.password)

      # Can't remember both users' devices?
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_url).to eq(saml_authn_request)
    end

    it 'does not render an error if a user goes back after opting to switch accounts' do
      sign_in_user(user1)
      visit saml_authn_request

      expect(current_path).to eq(user_authorization_confirmation_path)

      click_button t('user_authorization_confirmation.sign_in')
      # Simulate clicking the back button by going right back to the original path
      visit user_authorization_confirmation_path

      expect(current_path).to eq(new_user_session_path)
    end
  end
end
