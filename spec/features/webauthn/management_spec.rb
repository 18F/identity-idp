require 'rails_helper'

RSpec.describe 'webauthn management' do
  include WebAuthnHelper

  let(:user) { create(:user, :fully_registered, with: { phone: '+1 202-555-1212' }) }
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
    expect(page).to have_content t(
      'errors.webauthn_setup.general_error_html',
      link_html: t('errors.webauthn_setup.additional_methods_link'),
    )
    expect(current_path).to eq webauthn_setup_path
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
    expect(page).to have_content(t('notices.webauthn_platform_configured'))
  end

  def expect_webauthn_platform_setup_error
    expect(page).to have_content t('errors.webauthn_platform_setup.general_error')
    expect(current_path).to eq webauthn_setup_path
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
      webauthn_config1 = create(:webauthn_configuration, :platform_authenticator, user:)
      webauthn_config2 = create(:webauthn_configuration, :platform_authenticator, user:)

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_content webauthn_config1.name
      expect(page).to have_content webauthn_config2.name
    end

    it 'allows the user to setup another key' do
      mock_webauthn_setup_challenge
      create(:webauthn_configuration, :platform_authenticator, user:)

      sign_in_and_2fa_user(user)

      visit_webauthn_platform_setup

      expect(page).to have_current_path webauthn_setup_path(platform: true)

      # Regression: LG-9860: Ensure that the platform URL parameter is maintained through reauthn
      expire_reauthn_window
      mock_press_button_on_hardware_key_on_setup

      expect(page).to have_current_path login_two_factor_options_path
      click_on t('forms.buttons.continue')
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path webauthn_setup_path(platform: true)
      mock_press_button_on_hardware_key_on_setup

      expect_webauthn_platform_setup_success
    end

    it 'allows user to delete a platform authenticator when another 2FA option is set up' do
      webauthn_config = create(:webauthn_configuration, :platform_authenticator, user:)
      name = webauthn_config.name

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_content(name)

      click_link(
        format(
          '%s: %s',
          t('two_factor_authentication.webauthn_platform.manage_accessible_label'),
          name,
        ),
      )

      expect(current_path).to eq(edit_webauthn_path(id: webauthn_config.id))

      click_button t('two_factor_authentication.webauthn_platform.delete')

      expect(page).to_not have_content(name)
      expect(page).to have_content(t('two_factor_authentication.webauthn_platform.deleted'))
      expect(user.reload.webauthn_configurations.empty?).to eq(true)
    end

    it 'allows user to rename a platform authenticator' do
      webauthn_config = create(:webauthn_configuration, :platform_authenticator, user:)
      name = webauthn_config.name

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_content(name)

      click_link(
        format(
          '%s: %s',
          t('two_factor_authentication.webauthn_platform.manage_accessible_label'),
          name,
        ),
      )

      expect(current_path).to eq(edit_webauthn_path(id: webauthn_config.id))
      expect(page).to have_field(
        t('two_factor_authentication.webauthn_platform.nickname'),
        with: name,
      )

      fill_in t('two_factor_authentication.webauthn_platform.nickname'), with: 'new name'

      click_button t('two_factor_authentication.webauthn_platform.change_nickname')

      expect(page).to have_content('new name')
      expect(page).to have_content(t('two_factor_authentication.webauthn_platform.renamed'))
    end

    it 'allows the user to cancel deletion of the platform authenticator' do
      webauthn_config = create(:webauthn_configuration, :platform_authenticator, user:)
      name = webauthn_config.name

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_content(name)

      click_link(
        format(
          '%s: %s',
          t('two_factor_authentication.webauthn_platform.manage_accessible_label'),
          name,
        ),
      )

      expect(current_path).to eq(edit_webauthn_path(id: webauthn_config.id))

      click_link t('links.cancel')

      expect(page).to have_content(name)
    end

    it 'prevents a user from deleting the last key' do
      webauthn_config = create(:webauthn_configuration, :platform_authenticator, user:)
      name = webauthn_config.name

      sign_in_and_2fa_user(user)
      PhoneConfiguration.first.update(mfa_enabled: false)
      user.backup_code_configurations.destroy_all

      expect(page).to have_content(name)

      click_link(
        format(
          '%s: %s',
          t('two_factor_authentication.webauthn_platform.manage_accessible_label'),
          name,
        ),
      )

      expect(current_path).to eq(edit_webauthn_path(id: webauthn_config.id))

      click_button t('two_factor_authentication.webauthn_platform.delete')

      expect(page).to have_current_path(edit_webauthn_path(id: webauthn_config.id))
      expect(page).to have_content(t('errors.manage_authenticator.remove_only_method_error'))
      expect(user.reload.webauthn_configurations.empty?).to eq(false)
    end

    it 'requires a user to use a unique name when renaming' do
      webauthn_config = create(:webauthn_configuration, :platform_authenticator, user:)
      create(:webauthn_configuration, :platform_authenticator, user:, name: 'existing')
      name = webauthn_config.name

      sign_in_and_2fa_user(user)

      expect(page).to have_content(name)

      click_link(
        format(
          '%s: %s',
          t('two_factor_authentication.webauthn_platform.manage_accessible_label'),
          name,
        ),
      )

      expect(current_path).to eq(edit_webauthn_path(id: webauthn_config.id))
      expect(page).to have_field(
        t('two_factor_authentication.webauthn_platform.nickname'),
        with: name,
      )

      fill_in t('two_factor_authentication.webauthn_platform.nickname'), with: 'existing'

      click_button t('two_factor_authentication.webauthn_platform.change_nickname')

      expect(current_path).to eq(edit_webauthn_path(id: webauthn_config.id))
      expect(page).to have_field(
        t('two_factor_authentication.webauthn_platform.nickname'),
        with: 'existing',
      )
      expect(page).to have_content(t('errors.manage_authenticator.unique_name_error'))
    end

    it 'gives an error if name is taken and stays on the configuration screen' do
      webauthn_config = create(:webauthn_configuration, :platform_authenticator, user:)

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

    context 'with javascript enabled', :js do
      it 'allows user to delete a platform authenticator when another 2FA option is set up' do
        webauthn_config = create(:webauthn_configuration, :platform_authenticator, user:)
        name = webauthn_config.name

        sign_in_and_2fa_user(user)
        visit account_two_factor_authentication_path

        expect(page).to have_content(name)

        click_button(
          format(
            '%s: %s',
            t('two_factor_authentication.webauthn_platform.manage_accessible_label'),
            name,
          ),
        )

        # Verify user can cancel deletion. There's an implied assertion here that the button becomes
        # clickable again, since the following confirmation occurs upon successive button click.
        dismiss_confirm(wait: 5) { click_button t('components.manageable_authenticator.delete') }

        # Verify user confirms deletion
        accept_confirm(wait: 5) { click_button t('components.manageable_authenticator.delete') }

        expect(page).to have_content(
          t('two_factor_authentication.webauthn_platform.deleted'),
          wait: 5,
        )
        expect(page).to_not have_content(name)
        expect(user.reload.webauthn_configurations.empty?).to eq(true)
      end

      it 'allows user to rename a platform authenticator' do
        webauthn_config = create(:webauthn_configuration, :platform_authenticator, user:)
        name = webauthn_config.name

        sign_in_and_2fa_user(user)
        visit account_two_factor_authentication_path

        expect(page).to have_content(name)

        click_button(
          format(
            '%s: %s',
            t('two_factor_authentication.webauthn_platform.manage_accessible_label'),
            name,
          ),
        )
        click_button t('components.manageable_authenticator.rename')

        expect(page).to have_field(t('components.manageable_authenticator.nickname'), with: name)

        fill_in t('components.manageable_authenticator.nickname'), with: 'new name'

        click_button t('components.manageable_authenticator.save')

        expect(page).to have_content(
          t('two_factor_authentication.webauthn_platform.renamed'),
          wait: 5,
        )
        expect(page).to have_content('new name')
      end

      it 'prevents a user from deleting the last key', allow_browser_log: true do
        webauthn_config = create(:webauthn_configuration, :platform_authenticator, user:)
        name = webauthn_config.name

        sign_in_and_2fa_user(user)
        PhoneConfiguration.first.update(mfa_enabled: false)
        user.backup_code_configurations.destroy_all

        expect(page).to have_content(name)

        click_button(
          format(
            '%s: %s',
            t('two_factor_authentication.webauthn_platform.manage_accessible_label'),
            name,
          ),
        )
        accept_confirm(wait: 5) { click_button t('components.manageable_authenticator.delete') }

        expect(page).to have_content(
          t('errors.manage_authenticator.remove_only_method_error'),
          wait: 5,
        )
        expect(user.reload.webauthn_configurations.empty?).to eq(false)
      end

      it 'requires a user to use a unique name when renaming', allow_browser_log: true do
        webauthn_config = create(:webauthn_configuration, :platform_authenticator, user:)
        create(:webauthn_configuration, :platform_authenticator, user:, name: 'existing')
        name = webauthn_config.name

        sign_in_and_2fa_user(user)

        expect(page).to have_content(name)

        click_button(
          format(
            '%s: %s',
            t('two_factor_authentication.webauthn_platform.manage_accessible_label'),
            name,
          ),
        )
        click_button t('components.manageable_authenticator.rename')

        expect(page).to have_field(t('components.manageable_authenticator.nickname'), with: name)

        fill_in t('components.manageable_authenticator.nickname'), with: 'existing'

        click_button t('components.manageable_authenticator.save')

        expect(page).to have_content(t('errors.manage_authenticator.unique_name_error'), wait: 5)
      end
    end
  end
end
