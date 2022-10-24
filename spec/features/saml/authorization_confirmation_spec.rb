require 'rails_helper'

feature 'SAML Authorization Confirmation' do
  include SamlAuthHelper

  before do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(9999)
  end

  context 'authenticated user signs in to new sp' do
    def create_user_and_remember_device
      user = user_with_2fa

      sign_in_user(user)
      check t('forms.messages.remember_device')
      fill_in_code_with_last_phone_otp
      click_submit_default
      visit request_url
      click_agree_and_continue
      click_submit_default
      visit sign_out_url

      user
    end

    let(:user1) { create_user_and_remember_device }
    let(:user2) { create_user_and_remember_device }
    let(:request_url) { saml_authn_request_url }

    before do
      # Cycle user2 first so user1's remember device will stick
      user2
      user1
    end

    it 'it confirms the user wants to continue to SP with signin email after signing in again' do
      second_email = create(:email_address, user: user1)
      sign_in_user(user1, second_email.email)

      visit request_url
      expect(current_url).to match(user_authorization_confirmation_path)
      expect(page).to have_content second_email.email

      continue_as(second_email.email)
      expect(current_url).to eq(complete_saml_url)
    end

    it 'it allows the user to switch accounts prior to continuing to the SP' do
      sign_in_user(user1)

      visit request_url
      expect(current_url).to match(user_authorization_confirmation_path)
      continue_as(user2.email, user2.password)

      # Can't remember both users' devices?
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_url).to eq(complete_saml_url)
    end

    it 'does not render an error if a user goes back after opting to switch accounts' do
      sign_in_user(user1)
      visit request_url

      expect(current_path).to eq(user_authorization_confirmation_path)

      click_button t('user_authorization_confirmation.sign_in')
      # Simulate clicking the back button by going right back to the original path
      visit user_authorization_confirmation_path

      expect(current_path).to eq(new_user_session_path)
    end

    it 'does not render the confirmation screen on a return visit to the SP by default' do
      second_email = create(:email_address, user: user1)
      sign_in_user(user1, second_email.email)

      # first visit
      visit request_url
      continue_as(second_email.email)

      # second visit
      visit request_url
      expect(current_url).to eq(request_url)
    end

    it 'redirects to the account page with no sp in session' do
      sign_in_user(user1)
      visit user_authorization_confirmation_path

      expect(current_path).to eq(account_path)
    end
  end
end
