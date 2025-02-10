require 'rails_helper'

RSpec.describe 'Remembering a TOTP device' do
  before do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(1000)
  end

  let(:user) { create(:user, :fully_registered, :with_authentication_app) }

  context 'sign in' do
    def remember_device_and_sign_out_user
      sign_in_user(user)
      fill_in :code, with: generate_totp_code(user.auth_app_configurations.first.otp_secret_key)
      check t('forms.messages.remember_device')
      click_submit_default
      first(:button, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'sign up' do
    def remember_device_and_sign_out_user
      user = sign_up_and_set_password
      user.password = Features::SessionHelper::VALID_PASSWORD

      select_2fa_option('auth_app')
      fill_in_totp_name
      fill_in :code, with: totp_secret_from_page
      check t('forms.messages.remember_device')
      click_submit_default
      skip_second_mfa_prompt

      first(:button, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  context 'update totp' do
    def remember_device_and_sign_out_user
      auth_app_config = create(:auth_app_configuration, user:)
      name = auth_app_config.name

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      click_link(
        format(
          '%s: %s',
          t('two_factor_authentication.auth_app.manage_accessible_label'),
          name,
        ),
      )

      click_button t('two_factor_authentication.auth_app.delete')

      travel_to(10.seconds.from_now) # Travel past the revoked at date from disabling the device
      click_link t('account.index.auth_app_add'), href: authenticator_setup_url
      fill_in_totp_name
      fill_in :code, with: totp_secret_from_page
      check t('forms.messages.remember_device')
      click_submit_default
      expect(page).to have_current_path(account_path)
      first(:button, t('links.sign_out')).click
      user
    end

    it_behaves_like 'remember device'
  end

  def totp_secret_from_page
    secret = find('#qr-code').text
    generate_totp_code(secret)
  end
end
