require 'rails_helper'

feature 'User edit' do
  let(:user) { create(:user, :signed_up) }

  context 'editing email' do
    before do
      sign_in_and_2fa_user(user)
      visit manage_email_path
    end

    scenario 'user is not able to submit form without entering an email' do
      fill_in 'Email', with: ''
      click_button 'Update'

      expect(page).to have_current_path manage_email_path
    end
  end

  context 'editing 2FA phone number' do
    before do
      sign_in_and_2fa_user(user)
      visit manage_phone_path
    end

    scenario 'user sees error message if form is submitted without phone number', js: true do
      fill_in 'Phone', with: ''

      expect(page).to have_button(t('forms.buttons.submit.confirm_change'), disabled: true)
    end

    scenario 'user is able to submit with a Puerto Rico phone number as a US number', js: true do
      fill_in 'Phone', with: '787 555-1234'
      expect(page.find('#user_phone_form_international_code').value).to eq 'US'

      expect(page).to have_button(t('forms.buttons.submit.confirm_change'), disabled: false)
    end

    scenario 'confirms with selected OTP delivery method and updates user delivery preference' do
      allow(SmsOtpSenderJob).to receive(:perform_later)
      allow(VoiceOtpSenderJob).to receive(:perform_now)

      fill_in 'Phone', with: '555-555-5000'
      choose 'Phone call'

      click_button t('forms.buttons.submit.confirm_change')

      user.reload

      expect(current_path).to eq(login_otp_path(otp_delivery_preference: :voice))
      expect(SmsOtpSenderJob).to_not have_received(:perform_later)
      expect(VoiceOtpSenderJob).to have_received(:perform_now)
      expect(user.otp_delivery_preference).to eq('voice')
    end
  end

  context "user A accesses create password page with user B's email change token" do
    it "redirects to user A's account page", email: true do
      sign_in_and_2fa_user(user)
      visit manage_email_path
      fill_in 'Email', with: 'user_b_new_email@test.com'
      click_button 'Update'
      confirmation_link = parse_email_for_link(last_email, /confirmation_token/)
      token = confirmation_link.split('confirmation_token=').last
      visit destroy_user_session_path
      user_a = create(:user, :signed_up)
      sign_in_and_2fa_user(user_a)
      visit sign_up_enter_password_path(confirmation_token: token)

      expect(page).to have_current_path(account_path)
      expect(page).to_not have_content user.email
    end
  end

  context 'editing password' do
    before do
      sign_in_and_2fa_user(user)
      visit manage_password_path
    end

    scenario 'user sees error message if form is submitted with invalid password' do
      fill_in 'New password', with: 'foo'
      click_button 'Update'

      expect(page).
        to have_content t('errors.messages.too_short.other', count: Devise.password_length.first)
    end
  end
end
