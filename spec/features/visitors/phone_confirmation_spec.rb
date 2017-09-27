require 'rails_helper'

feature 'Phone confirmation during sign up' do
  context 'visitor can sign up and confirm a valid phone for OTP' do
    before do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      allow(SmsOtpSenderJob).to receive(:perform_now)
      @user = sign_in_before_2fa
      fill_in 'Phone', with: '555-555-5555'
      click_send_security_code

      expect(SmsOtpSenderJob).to have_received(:perform_now).with(
        code: @user.reload.direct_otp,
        phone: '+1 (555) 555-5555',
        otp_created_at: @user.direct_otp_sent_at.to_s
      )
    end

    it 'updates phone_confirmed_at and redirects to acknowledge personal key' do
      click_button t('forms.buttons.submit.default')

      expect(@user.reload.phone_confirmed_at).to be_present
      expect(current_path).to eq sign_up_personal_key_path

      click_acknowledge_personal_key

      expect(current_path).to eq account_path
    end

    it 'allows user to resend confirmation code' do
      click_link t('links.two_factor_authentication.resend_code.sms')

      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
    end

    it 'does not enable 2FA until correct OTP is entered' do
      fill_in 'code', with: '12345678'
      click_button t('forms.buttons.submit.default')

      expect(@user.reload.two_factor_enabled?).to be false
    end

    it 'provides user with link to type in a phone number so they are not locked out' do
      click_link t('forms.two_factor.try_again')
      expect(current_path).to eq phone_setup_path
    end

    it 'informs the user that the OTP code is sent to the phone' do
      expect(page).to have_content(
        t('instructions.mfa.sms.confirm_code_html',
          number: '+1 (555) 555-5555',
          resend_code_link: t('links.two_factor_authentication.resend_code.sms'))
      )
    end
  end

  context "visitor tries to sign up with another user's phone for OTP" do
    before do
      @existing_user = create(:user, :signed_up)
      @user = sign_in_before_2fa
      fill_in 'Phone', with: @existing_user.phone
      click_send_security_code
    end

    it 'pretends the phone is valid and prompts to confirm the number' do
      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
      expect(page).to have_content(
        t('instructions.mfa.sms.confirm_code_html',
          number: @existing_user.phone,
          resend_code_link: t('links.two_factor_authentication.resend_code.sms'))
      )
    end

    it 'does not confirm the new number with an invalid code' do
      fill_in 'code', with: 'foobar'
      click_submit_default

      expect(@user.reload.phone_confirmed_at).to be_nil
      expect(page).to have_content t('devise.two_factor_authentication.invalid_otp')
      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
    end
  end
end
