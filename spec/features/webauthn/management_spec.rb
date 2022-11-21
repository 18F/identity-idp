require 'rails_helper'

describe 'webauthn management' do
  include WebAuthnHelper

  let(:user) { create(:user, :signed_up, with: { phone: '+1 202-555-1212' }) }
  let(:view) { ActionController::Base.new.view_context }

  it_behaves_like 'webauthn setup'

  def visit_webauthn_setup
    sign_in_and_2fa_user(user)
    visit account_two_factor_authentication_path
    first(:link, t('account.index.webauthn_add'), href: webauthn_setup_path).click
  end

  def expect_webauthn_setup_success
    expect(page).to have_content(t('notices.webauthn_configured'))
    expect(page).to have_current_path(account_two_factor_authentication_path)
  end

  def expect_webauthn_setup_error
    expect(page).to have_content t('errors.webauthn_setup.general_error')
    expect(current_path).to eq account_two_factor_authentication_path
  end

  def visit_webauthn_platform_setup
    sign_in_and_2fa_user(user)
    visit account_two_factor_authentication_path
    first(
      :link,
      t('account.index.webauthn_platform_add'),
      href: webauthn_setup_path(platform: true),
    ).click
  end

  def expect_webauthn_platform_setup_success
    expect(page).to have_content(t('notices.webauthn_platform_configured'))
    expect(page).to have_current_path(account_two_factor_authentication_path)
  end

  def expect_webauthn_platform_setup_error
    expect(page).to have_content t('errors.webauthn_platform_setup.general_error')
    expect(current_path).to eq account_two_factor_authentication_path
  end

  context 'with webauthn roaming associations' do
    it 'displays the user supplied names of the security keys' do
      webauthn_config1 = create(:webauthn_configuration, user: user)
      webauthn_config2 = create(:webauthn_configuration, user: user)

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_content webauthn_config1.name
      expect(page).to have_content webauthn_config2.name
    end

    it 'allows the user to setup another key' do
      mock_webauthn_setup_challenge
      create(:webauthn_configuration, user: user)

      sign_in_and_2fa_user(user)

      visit_webauthn_setup

      expect(current_path).to eq webauthn_setup_path

      fill_in_nickname_and_click_continue
      mock_press_button_on_hardware_key_on_setup

      expect_webauthn_setup_success
    end

    it 'allows user to delete security key when another 2FA option is set up' do
      webauthn_config = create(:webauthn_configuration, user: user)

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_content webauthn_config.name

      click_link t('account.index.webauthn_delete')

      expect(current_path).to eq webauthn_setup_delete_path

      click_button t('account.index.webauthn_confirm_delete')

      expect(page).to_not have_content webauthn_config.name
      expect(page).to have_content t('notices.webauthn_deleted')
      expect(user.reload.webauthn_configurations.empty?).to eq(true)
    end

    it 'allows the user to cancel deletion of the security key' do
      webauthn_config = create(:webauthn_configuration, user: user)

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_content webauthn_config.name

      click_link t('account.index.webauthn_delete')

      expect(current_path).to eq webauthn_setup_delete_path

      click_link t('links.cancel')

      expect(page).to have_content webauthn_config.name
    end

    it 'prevents a user from deleting the last key' do
      webauthn_config = create(:webauthn_configuration, user: user)

      sign_in_and_2fa_user(user)
      PhoneConfiguration.first.update(mfa_enabled: false)
      user.backup_code_configurations.destroy_all

      visit account_two_factor_authentication_path
      expect(current_path).to eq account_two_factor_authentication_path

      expect(page).to have_content webauthn_config.name
      expect(page).to_not have_link t('account.index.webauthn_delete')
    end

    it 'gives an error if name is taken and stays on the configuration screen' do
      webauthn_config = create(:webauthn_configuration, user: user)

      mock_webauthn_setup_challenge
      sign_in_and_2fa_user(user)

      visit account_two_factor_authentication_path
      expect(current_path).to eq account_two_factor_authentication_path

      first(:link, t('account.index.webauthn_add'), href: webauthn_setup_path).click
      expect(current_path).to eq webauthn_setup_path

      fill_in_nickname_and_click_continue(nickname: webauthn_config.name)
      mock_press_button_on_hardware_key_on_setup

      expect(current_path).to eq webauthn_setup_path
      expect(page).to have_content t('errors.webauthn_setup.unique_name')
    end
  end

  context 'with webauthn platform associations' do
    it 'displays the user supplied names of the platform authenticators' do
      webauthn_config1 = create(:webauthn_configuration, user: user, platform_authenticator: true)
      webauthn_config2 = create(:webauthn_configuration, user: user, platform_authenticator: true)

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_content webauthn_config1.name
      expect(page).to have_content webauthn_config2.name
    end

    context 'with webauthn platform set up enabled' do
      before do
        allow(IdentityConfig.store).to receive(:platform_auth_set_up_enabled).and_return(true)
      end

      it 'allows the user to setup another key' do
        mock_webauthn_setup_challenge
        create(:webauthn_configuration, user: user, platform_authenticator: true)

        sign_in_and_2fa_user(user)

        visit_webauthn_platform_setup

        expect(page).to have_current_path webauthn_setup_path(platform: true)

        fill_in_nickname_and_click_continue
        mock_press_button_on_hardware_key_on_setup

        expect_webauthn_platform_setup_success
      end
    end

    context 'with platform auth set up disabled' do
      before do
        allow(IdentityConfig.store).to receive(:platform_auth_set_up_enabled).and_return(false)
      end

      it 'does not allows the user to setup another platform authenticator' do
        mock_webauthn_setup_challenge
        create(:webauthn_configuration, user: user, platform_authenticator: true)

        sign_in_and_2fa_user(user)

        expect(page).
          to_not have_content t('account.index.webauthn_platform_add')
      end
    end

    it 'allows user to delete a platform authenticator when another 2FA option is set up' do
      webauthn_config = create(:webauthn_configuration, user: user, platform_authenticator: true)

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_content webauthn_config.name

      click_link t('account.index.webauthn_platform_delete')

      expect(current_path).to eq webauthn_setup_delete_path

      click_button t('account.index.webauthn_platform_confirm_delete')

      expect(page).to_not have_content webauthn_config.name
      expect(page).to have_content t('notices.webauthn_platform_deleted')
      expect(user.reload.webauthn_configurations.empty?).to eq(true)
    end

    it 'allows the user to cancel deletion of the platform authenticator' do
      webauthn_config = create(:webauthn_configuration, user: user, platform_authenticator: true)

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_content webauthn_config.name

      click_link t('account.index.webauthn_platform_delete')

      expect(current_path).to eq webauthn_setup_delete_path

      click_link t('links.cancel')

      expect(page).to have_content webauthn_config.name
    end

    it 'prevents a user from deleting the last key' do
      webauthn_config = create(:webauthn_configuration, user: user, platform_authenticator: true)

      sign_in_and_2fa_user(user)
      PhoneConfiguration.first.update(mfa_enabled: false)
      user.backup_code_configurations.destroy_all

      visit account_two_factor_authentication_path
      expect(current_path).to eq account_two_factor_authentication_path

      expect(page).to have_content webauthn_config.name
      expect(page).to_not have_link t('account.index.webauthn_platform_delete')
    end

    it 'gives an error if name is taken and stays on the configuration screen' do
      webauthn_config = create(:webauthn_configuration, user: user, platform_authenticator: true)

      mock_webauthn_setup_challenge
      sign_in_and_2fa_user(user)

      visit account_two_factor_authentication_path
      expect(current_path).to eq account_two_factor_authentication_path

      first(:link, t('account.index.webauthn_add'), href: webauthn_setup_path).click
      expect(current_path).to eq webauthn_setup_path

      fill_in_nickname_and_click_continue(nickname: webauthn_config.name)
      mock_press_button_on_hardware_key_on_setup

      expect(current_path).to eq webauthn_setup_path
      expect(page).to have_content t('errors.webauthn_platform_setup.unique_name')
    end
  end
end
