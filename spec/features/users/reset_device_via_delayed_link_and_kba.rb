require 'rails_helper'

feature 'Reset Device via Delayed Link and KBA Security Questions' do
  context 'user resets authentication device' do
    it 'redirects to the root if there is no user' do
      visit login_two_factor_reset_device_url
      expect(current_url).to eq root_url
    end

    it 'redirects to confirmation page' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      click_link t('devise.two_factor_authentication.reset_device.link')
      expect(current_path).to eq login_two_factor_reset_device_path
    end

    it 'redirects to login page after confirming and gets success message' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      click_link t('devise.two_factor_authentication.reset_device.link')
      expect(current_path).to eq login_two_factor_reset_device_path
      click_button t('devise.two_factor_authentication.reset_device.header_text')
      expect(current_url).to eq root_url
      expect(page).to(
        have_content(t('devise.two_factor_authentication.reset_device.success_message'))
      )
    end

    it 'shows request pending if not waiting the full wait period' do
      allow(Figaro.env).to receive(:reset_device_wait_period_days).and_return('2')
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      click_link t('devise.two_factor_authentication.reset_device.link')
      click_button t('devise.two_factor_authentication.reset_device.header_text')
      sign_in_before_2fa(user)
      expect(page).to have_content t('devise.two_factor_authentication.reset_device.cancel_link')
    end

    it 'allows you to cancel the reset device request if not waiting the full wait period' do
      allow(Figaro.env).to receive(:reset_device_wait_period_days).and_return('2')
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      click_link t('devise.two_factor_authentication.reset_device.link')
      click_button t('devise.two_factor_authentication.reset_device.header_text')
      sign_in_before_2fa(user)
      click_link t('devise.two_factor_authentication.reset_device.cancel_link')

      expect(current_url).to eq root_url
    end

    it 'allows signing in and phone change after getting granted link and answering kba' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      click_link t('devise.two_factor_authentication.reset_device.link')
      click_button t('devise.two_factor_authentication.reset_device.header_text')

      ResetDevice.new(user).grant_request # an async rake task grants requests after 72 hours

      url = change_phone_url(token: ChangePhoneRequest.find_by(user_id: user.id).granted_token)
      visit url
      expect(current_url).to eq url

      select 'Other', from: 'kba_security_form_answer'
      click_submit_default
      expect(current_url).to eq root_url

      sign_in_before_2fa(user)
      expect(current_url).to eq manage_phone_url
      fill_in 'Phone', with: '202-555-1212'
      click_button t('forms.buttons.submit.confirm_change')
      expect(current_path).to eq account_path
    end

    it 'prevents signing in and phone change after getting granted link and not answering kba' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      click_link t('devise.two_factor_authentication.reset_device.link')
      click_button t('devise.two_factor_authentication.reset_device.header_text')

      ResetDevice.new(user).grant_request

      url = change_phone_url(token: ChangePhoneRequest.find_by(user_id: user.id).granted_token)
      visit url
      expect(current_url).to eq url

      select 'Select an answer...', from: 'kba_security_form_answer'
      click_submit_default
      expect(current_url).to eq url

      visit root_url
      sign_in_before_2fa(user)
      expect(page).
        to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false))
    end

    it 'prevents signing in and phone change after getting granted link and failing kba' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      click_link t('devise.two_factor_authentication.reset_device.link')
      click_button t('devise.two_factor_authentication.reset_device.header_text')

      ResetDevice.new(user).grant_request

      url = change_phone_url(token: ChangePhoneRequest.find_by(user_id: user.id).granted_token)
      visit url
      expect(current_url).to eq url

      select 'USA JOBS', from: 'kba_security_form_answer'
      click_submit_default
      expect(current_url).to eq root_url

      sign_in_before_2fa(user)
      expect(page).
        to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms', reauthn: false))
    end

    it 'link is not reusable after answering kba' do
      user = create(:user, :signed_up)
      sign_in_before_2fa(user)
      click_link t('devise.two_factor_authentication.reset_device.link')
      click_button t('devise.two_factor_authentication.reset_device.header_text')

      ResetDevice.new(user).grant_request # an async rake task grants requests after 72 hours

      url = change_phone_url(token: ChangePhoneRequest.find_by(user_id: user.id).granted_token)
      visit url
      expect(current_url).to eq url

      select 'USA JOBS', from: 'kba_security_form_answer'
      click_submit_default
      expect(current_url).to eq root_url

      visit url
      expect(current_url).to eq root_url
    end
  end
end
