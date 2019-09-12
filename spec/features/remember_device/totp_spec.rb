require 'rails_helper'

describe 'Remembering a TOTP device' do
  before do
    allow(Figaro.env).to receive(:otp_delivery_blocklist_maxretry).and_return('1000')
  end

  let(:user) { create(:user, :signed_up, :with_authentication_app) }

  context 'sign in' do
    def remember_device_and_sign_out_user
      sign_in_user(user)
      fill_in :code, with: generate_totp_code(user.otp_secret_key)
      check :remember_device
      click_submit_default
      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'sign up with remember_device last' do
    def remember_device_and_sign_out_user
      user = sign_up_and_set_password
      user.password = Features::SessionHelper::VALID_PASSWORD

      select_2fa_option('phone')
      fill_in :user_phone_form_phone, with: '2025551212'
      click_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default

      click_continue

      select_2fa_option('auth_app')
      fill_in :code, with: totp_secret_from_page
      check :remember_device
      click_submit_default

      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'sign up with remember_device first' do
    def remember_device_and_sign_out_user
      user = sign_up_and_set_password
      user.password = Features::SessionHelper::VALID_PASSWORD

      select_2fa_option('auth_app')
      fill_in :code, with: totp_secret_from_page
      check :remember_device
      click_submit_default

      click_continue

      select_2fa_option('phone')
      fill_in :user_phone_form_phone, with: '2025551212'
      click_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default

      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'update totp' do
    after do
      Timecop.return
    end

    def remember_device_and_sign_out_user
      sign_in_and_2fa_user(user)
      click_on t('forms.buttons.disable')
      Timecop.travel 5.seconds.from_now # Travel past the revoked at date from disabling the device
      click_link t('forms.buttons.enable'), href: authenticator_setup_url
      fill_in :code, with: totp_secret_from_page
      check :remember_device
      click_submit_default
      expect(page).to have_current_path(account_path)
      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  def totp_secret_from_page
    secret = find('#qr-code').text
    generate_totp_code(secret)
  end
end
