require 'rails_helper'

feature 'Phone confirmation during sign up' do
  context 'visitor can sign up and confirm a valid phone for OTP' do
    before do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      allow(SmsOtpSenderJob).to receive(:perform_now)
      @user = sign_in_before_2fa
      select_2fa_option('sms')
      fill_in 'user_phone_form_phone', with: '703-555-5555'
      click_send_security_code

      expect(SmsOtpSenderJob).to have_received(:perform_now).with(
        code: @user.reload.direct_otp,
        phone: '+1 703-555-5555',
        otp_created_at: @user.direct_otp_sent_at.to_s,
        message: 'jobs.sms_otp_sender_job.verify_message',
        locale: nil
      )
    end

    it 'updates phone_confirmed_at and redirects to acknowledge personal key' do
      click_button t('forms.buttons.submit.default')

      expect(MfaContext.new(@user).phone_configurations.reload.first.confirmed_at).to be_present
      expect(current_path).to eq sign_up_personal_key_path

      click_acknowledge_personal_key

      expect(current_path).to eq account_path
    end

    it 'allows user to resend confirmation code' do
      click_link t('links.two_factor_authentication.get_another_code')

      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
    end

    it 'does not enable 2FA until correct OTP is entered' do
      fill_in 'code', with: '12345678'
      click_button t('forms.buttons.submit.default')

      expect(MfaPolicy.new(@user.reload).two_factor_enabled?).to be false
    end

    it 'provides user with link to type in a phone number so they are not locked out' do
      click_link t('forms.two_factor.try_again')
      expect(current_path).to eq phone_setup_path
    end

    it 'informs the user that the OTP code is sent to the phone' do
      expect(page).to have_content(t('instructions.mfa.sms.number_message',
                                     number: '+1 703-555-5555',
                                     expiration: Figaro.env.otp_valid_for))
    end
  end

  context "visitor tries to sign up with another user's phone for OTP" do
    before do
      @existing_user = create(:user, :signed_up)
      @user = sign_in_before_2fa
      select_2fa_option('sms')
      fill_in 'user_phone_form_phone',
              with: MfaContext.new(@existing_user).phone_configurations.detect(&:mfa_enabled?).phone
      click_send_security_code
    end

    it 'pretends the phone is valid and prompts to confirm the number' do
      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
      expect(page).to have_content(t('instructions.mfa.sms.number_message',
                                     number: '+1 202-555-1212',
                                     expiration: Figaro.env.otp_valid_for))
    end

    it 'does not confirm the new number with an invalid code' do
      fill_in 'code', with: 'foobar'
      click_submit_default

      expect(MfaContext.new(@user).phone_configurations.reload).to be_empty
      expect(page).to have_content t('two_factor_authentication.invalid_otp')
      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: 'sms')
    end
  end
end
