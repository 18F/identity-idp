require 'rails_helper'

describe 'Remembering a TOTP device' do
  before do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(1000)
  end

  let(:user) { create(:user, :signed_up, :with_authentication_app) }

  context 'sign in' do
    def remember_device_and_sign_out_user
      sign_in_user(user)
      fill_in :code, with: generate_totp_code(user.auth_app_configurations.first.otp_secret_key)
      check t('forms.messages.remember_device')
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

      select_2fa_option('auth_app')
      fill_in t('forms.totp_setup.totp_step_1'), with: 'App'
      fill_in :code, with: totp_secret_from_page
      check t('forms.messages.remember_device')
      click_submit_default
      skip_second_mfa_prompt

      first(:link, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'update totp' do
    def remember_device_and_sign_out_user
      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path
      page.find('.remove-auth-app').click # Delete
      click_on t('account.index.totp_confirm_delete')
      travel_to(10.seconds.from_now) # Travel past the revoked at date from disabling the device
      click_link t('account.index.auth_app_add'), href: authenticator_setup_url
      fill_in t('forms.totp_setup.totp_step_1'), with: 'App'
      fill_in :code, with: totp_secret_from_page
      check t('forms.messages.remember_device')
      click_submit_default
      expect(page).to have_current_path(account_two_factor_authentication_path)
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
