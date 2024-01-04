require 'rails_helper'

RSpec.feature 'OIDC Authorization Confirmation' do
  include OidcAuthHelper

  before do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(9999)
  end

  context 'authenticated user signs in to new sp' do
    def create_user_and_remember_device
      user = user_with_2fa

      sign_in_oidc_user(user)
      check t('forms.messages.remember_device')
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
      expect(oidc_redirect_url).to match('http://localhost:7654/auth/result')
    end

    it 'it allows the user to switch accounts prior to continuing to the SP' do
      sign_in_user(user1)
      visit_idp_from_ial1_oidc_sp
      expect(current_url).to match(user_authorization_confirmation_path)

      continue_as(user2.email, user2.password)

      # Can't remember both users' devices?
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(oidc_redirect_url).to match('http://localhost:7654/auth/result')
    end

    it 'does not render the confirmation screen on a return visit to the SP by default' do
      second_email = create(:email_address, user: user1)
      sign_in_user(user1, second_email.email)

      # first visit
      visit_idp_from_ial1_oidc_sp
      continue_as(second_email.email)

      # second visit
      visit_idp_from_ial1_oidc_sp
      expect(oidc_redirect_url).to match('http://localhost:7654/auth/result')
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

  context 'first time registration' do
    it 'redirects user to sp and does not go through authorization_confirmation page' do
      email = 'test@test.com'

      perform_in_browser(:one) do
        visit visit_idp_from_ial1_oidc_sp
        sign_up_user_from_sp_without_confirming_email(email)
      end

      perform_in_browser(:two) do
        confirm_email_in_a_different_browser(email)
        expect(current_path).to eq sign_up_completed_path
        expect(page).to have_content t('help_text.requested_attributes.email')
        expect(page).to have_content email

        click_agree_and_continue

        expect(oidc_redirect_url).to match('http://localhost:7654/auth/result')
        expect(page.get_rack_session.keys).to include('sp')
      end
    end
  end

  context 'when asked for selfie verification in production' do
    before do
      allow(Rails.env).to receive(:production?).and_return(true)
      visit visit_idp_from_ial2_oidc_sp(biometric_comparison_required: true)
    end

    it 'redirects to the 406 (unacceptable) page' do
      expect(page.status_code).to eq(406)
    end
  end
end
