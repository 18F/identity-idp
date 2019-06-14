require 'rails_helper'

feature 'OTP delivery selection' do
  context 'set up voice as 2FA' do
    before do
      sign_in_user
      select_2fa_option('voice')
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default
    end

    it 'allows the user to setup SMS for backup MFA' do
      expect(page).to have_current_path(two_factor_options_path)
      select_2fa_option('sms')
      expect(page).to have_content t('titles.phone_setup.sms')
      fill_in 'user_phone_form[phone]', with: '202-555-1213'
      click_send_security_code
      expect(page).to have_content(t('instructions.mfa.sms.number_message',
                                     number: '+1 202-555-1213',
                                     expiration: Figaro.env.otp_valid_for))
    end
  end

  context 'set up SMS as 2FA' do
    before do
      sign_in_user
      select_2fa_option('sms')
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default
    end

    it 'allows the user to voice for backup MFA' do
      expect(page).to have_current_path(two_factor_options_path)
      select_2fa_option('voice')
      expect(page).to have_content t('titles.phone_setup.voice')
      fill_in 'user_phone_form[phone]', with: '202-555-1213'
      click_send_security_code
      expect(page).to have_content(t('instructions.mfa.voice.number_message',
                                     number: '+1 202-555-1213',
                                     expiration: Figaro.env.otp_valid_for))
    end
  end

  it 'allows the user to select a backup delivery method and then change that selection' do
    sign_in_user
    select_2fa_option(:sms)
    fill_in :user_phone_form_phone, with: '202-555-1212'
    click_send_security_code
    fill_in_code_with_last_phone_otp
    click_submit_default
    select_2fa_option(:voice)

    expect(page).to have_content(t('titles.phone_setup.voice'))

    click_on t('two_factor_authentication.choose_another_option')
    select_2fa_option(:sms)

    expect(page).to have_content(t('titles.phone_setup.sms'))

    Twilio::FakeCall.calls = []
    Twilio::FakeMessage.messages = []

    fill_in :user_phone_form_phone, with: '202-555-1313'
    click_send_security_code

    expect(Twilio::FakeCall.calls.length).to eq(0)
    expect(Twilio::FakeMessage.messages.length).to eq(1)

    expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))

    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(page).to have_current_path(account_path)
  end
end
