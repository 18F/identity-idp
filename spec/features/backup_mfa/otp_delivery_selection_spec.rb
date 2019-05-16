require 'rails_helper'

feature 'OTP delivery selection' do
  context 'set up voice as 2FA' do
    before do
      sign_in_user
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      select_2fa_option('voice')
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
      click_submit_default
    end

    it 'then set up SMS as backup MFA' do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      expect(page).to have_current_path(two_factor_options_path)
      select_2fa_option('sms')
      expect(page).to have_content t('titles.phone_setup.sms')
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
      expect(page).to have_content(t('instructions.mfa.sms.number_message',
                                     number: '+1 202-555-1212',
                                     expiration: Figaro.env.otp_valid_for))
    end
  end

  context 'set up SMS as 2FA' do
    before do
      sign_in_user
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      select_2fa_option('sms')
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
      click_submit_default
    end

    it 'then set up voice as backup MFA' do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      expect(page).to have_current_path(two_factor_options_path)
      select_2fa_option('voice')
      expect(page).to have_content t('titles.phone_setup.voice')
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
      expect(page).to have_content(t('instructions.mfa.voice.number_message',
                                     number: '+1 202-555-1212',
                                     expiration: Figaro.env.otp_valid_for))
    end
  end
end
