require 'rails_helper'

feature 'Remembering a 2FA device' do
  include IdvHelper

  before do
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    allow(SmsOtpSenderJob).to receive(:perform_now)
    allow(Figaro.env).to receive(:otp_delivery_blocklist_maxretry).and_return('1000')
  end

  let(:user) { user_with_2fa }

  context 'sign in' do
    def remember_device_and_sign_out_user
      user = user_with_2fa
      sign_in_user(user)
      check :remember_device
      click_submit_default
      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'sign up' do
    def remember_device_and_sign_out_user
      user = sign_up_and_set_password
      user.password = Features::SessionHelper::VALID_PASSWORD
      fill_in :user_phone_form_phone, with: '5551231234'
      click_send_security_code
      check :remember_device
      click_submit_default
      click_acknowledge_personal_key
      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'update phone number' do
    def remember_device_and_sign_out_user
      user = user_with_2fa
      sign_in_and_2fa_user(user)
      visit manage_phone_path
      fill_in 'user_phone_form_phone', with: '5552347193'
      click_button t('forms.buttons.submit.confirm_change')
      check :remember_device
      click_submit_default
      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'

    it 'requires the user to confirm the new phone number' do
      user = user_with_2fa
      sign_in_user(user)
      check :remember_device
      click_submit_default

      visit manage_phone_path
      fill_in 'user_phone_form_phone', with: '5552347193'
      click_button t('forms.buttons.submit.confirm_change')

      expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))
    end
  end

  context 'identity verification', :idv_job do
    let(:user) { user_with_2fa }

    before do
      sign_in_user(user)
      check :remember_device
      click_submit_default
      visit idv_session_path
      fill_out_idv_form_ok
      click_idv_continue
      click_idv_continue
      click_idv_address_choose_phone
      fill_out_phone_form_ok('5551603829')
      click_idv_continue
      choose_idv_otp_delivery_method_sms
    end

    it 'requires 2FA and does not offer the option to remember device' do
      expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))
      expect(page).to_not have_content(
        t('forms.messages.remember_device', duration: Figaro.env.remember_device_expiration_days!)
      )
    end
  end

  context 'totp' do
    let(:user) do
      user = build(:user, :signed_up, password: 'super strong password')
      @secret = user.generate_totp_secret
      UpdateUser.new(user: user, attributes: { otp_secret_key: @secret }).call
      user
    end

    it 'does not offer the option to remember device' do
      sign_in_user(user)
      expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :authenticator))
      expect(page).to_not have_content(
        t('forms.messages.remember_device', duration: Figaro.env.remember_device_expiration_days!)
      )
    end
  end
end
