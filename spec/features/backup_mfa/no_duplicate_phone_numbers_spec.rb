require 'rails_helper'

feature 'OTP delivery selection' do
  context 'set up a number as 2FA for voice' do
    before do
      sign_in_user
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      select_2fa_option('voice')
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
      click_submit_default
    end

    it 'should fail if using the same number as backup MFA voice' do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      expect(page).to have_current_path(two_factor_options_path)
      select_2fa_option('voice')
      expect(page).to have_content t('titles.phone_setup.voice')
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
      expect(page).to have_content(t('errors.messages.phone_duplicate'))
    end

    it 'should success if using a new number as backup MFA voice' do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      expect(page).to have_current_path(two_factor_options_path)
      select_2fa_option('voice')
      expect(page).to have_content t('titles.phone_setup.voice')
      fill_in 'user_phone_form[phone]', with: '202-555-1213'
      click_send_security_code
      expect(page).to have_content(t('two_factor_authentication.header_text'))
    end
  end
end