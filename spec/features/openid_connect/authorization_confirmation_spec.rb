require 'rails_helper'

feature 'OIDC Authorization Confirmation' do
  include OidcAuthHelper

  before do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(9999)
  end

  context 'authenticated user signs in to new sp' do
    def create_user_and_remember_device
      user = user_with_2fa

      sign_in_oidc_user(user)
      check :remember_device
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_agree_and_continue

      visit sign_out_url

      user
    end

    let(:user1) { create_user_and_remember_device }
    let(:user2) { create_user_and_remember_device }

    before do
      # Cycle user2 first so user1's remember device will stick
      user2
      user1
    end

    it 'it confirms the user wants to continue to SP with signin email after signing in again' do
      second_email = create(:email_address, user: user1)
      sign_in_user(user1, second_email.email)
      visit_idp_from_ial1_oidc_sp
      expect(current_url).to match(user_authorization_confirmation_path)
      expect(page).to have_content second_email.email

      continue_as(second_email.email)
      expect(current_url).to match('http://localhost:7654/auth/result')
    end

    it 'it allows the user to switch accounts prior to continuing to the SP' do
      sign_in_user(user1)
      visit_idp_from_ial1_oidc_sp
      expect(current_url).to match(user_authorization_confirmation_path)

      continue_as(user2.email, user2.password)

      # Can't remember both users' devices?
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_url).to match('http://localhost:7654/auth/result')
    end

    it 'does not render an error if a user goes back after opting to switch accounts' do
      sign_in_user(user1)
      visit_idp_from_ial1_oidc_sp

      expect(current_path).to eq(user_authorization_confirmation_path)

      click_button t('user_authorization_confirmation.sign_in')
      # Simulate clicking the back button by going right back to the original path
      visit user_authorization_confirmation_path

      expect(current_path).to eq(new_user_session_path)
    end
  end
end
