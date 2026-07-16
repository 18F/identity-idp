require 'rails_helper'

RSpec.describe 'totp management' do
  context 'when the user has totp enabled' do
    let(:user) { create(:user, :fully_registered, :with_authentication_app) }

    it 'allows user to delete a platform authenticator when another 2FA option is set up' do
      auth_app_config = create(:auth_app_configuration, user:)
      name = auth_app_config.name

      sign_in_and_2fa_user(user)
      visit account_security_path

      expect(user.reload.auth_app_configurations.count).to eq(2)
      expect(page).to have_content(name)

      click_link(
        format(
          '%s: %s',
          t('two_factor_authentication.auth_app.manage_accessible_label'),
          name,
        ),
      )

      expect(page).to have_current_path(edit_auth_app_path(id: auth_app_config.id))

      click_link t('two_factor_authentication.auth_app.delete')

      expect(page).to have_current_path(confirm_delete_auth_app_path(id: auth_app_config.id))

      click_button t('two_factor_authentication.auth_app.delete')

      expect(page).to have_content(t('two_factor_authentication.auth_app.deleted'))
      expect(user.reload.auth_app_configurations.count).to eq(1)
    end

    it 'allows user to rename an authentication app app' do
      auth_app_configuration = create(:auth_app_configuration, user:)
      name = auth_app_configuration.name

      sign_in_and_2fa_user(user)
      visit account_security_path

      expect(page).to have_content(name)

      click_link(
        format(
          '%s: %s',
          t('two_factor_authentication.auth_app.manage_accessible_label'),
          name,
        ),
      )

      expect(page).to have_current_path(edit_auth_app_path(id: auth_app_configuration.id))
      expect(page).to have_field(
        t('two_factor_authentication.auth_app.nickname'),
        with: name,
      )

      fill_in t('two_factor_authentication.auth_app.nickname'), with: 'new name'

      click_button t('two_factor_authentication.auth_app.change_nickname')

      expect(page).to have_content(t('two_factor_authentication.auth_app.renamed'))

      visit account_security_path
      expect(page).to have_content('new name')
    end

    it 'requires a user to use a unique name when renaming' do
      existing_auth_app_configuration = create(:auth_app_configuration, user:, name: 'existing')
      new_app_auth_configuration = create(:auth_app_configuration, user:, name: 'new existing')
      name = existing_auth_app_configuration.name

      sign_in_and_2fa_user(user)
      visit account_security_path

      expect(page).to have_content(name)

      click_link(
        format(
          '%s: %s',
          t('two_factor_authentication.auth_app.manage_accessible_label'),
          name,
        ),
      )

      expect(page).to have_current_path(edit_auth_app_path(id: existing_auth_app_configuration.id))
      expect(page).to have_field(
        t('two_factor_authentication.auth_app.nickname'),
        with: name,
      )

      fill_in t('two_factor_authentication.auth_app.nickname'),
              with: new_app_auth_configuration.name

      click_button t('two_factor_authentication.auth_app.change_nickname')

      expect(page).to have_current_path(edit_auth_app_path(id: existing_auth_app_configuration.id))

      expect(page).to have_content(t('errors.manage_authenticator.unique_name_error'))
    end
  end

  context 'when totp is the only mfa method' do
    let(:user) { create(:user, :with_authentication_app) }

    it 'prevents a user from deleting their last authenticator' do
      sign_in_and_2fa_user(user)
      visit account_security_path

      configuration = user.auth_app_configurations.first

      click_link(
        format(
          '%s: %s',
          t('two_factor_authentication.auth_app.manage_accessible_label'),
          configuration.name,
        ),
      )

      click_link t('two_factor_authentication.auth_app.delete')

      expect(page).to have_current_path(confirm_delete_auth_app_path(id: configuration.id))

      click_button t('two_factor_authentication.auth_app.delete')

      expect(page).to have_content(t('errors.manage_authenticator.remove_only_method_error'))
      expect(user.reload.auth_app_configurations.count).to eq(1)
    end
  end

  context 'when the user has totp disabled' do
    let(:user) { create(:user, :fully_registered) }

    it 'allows the user to setup a totp app' do
      sign_in_and_2fa_user(user)
      visit account_security_path

      click_link t('account.index.auth_app_add'), href: authenticator_setup_url

      expect(page).to have_css('h2#totp-step-1-label', text: t('forms.totp_setup.totp_step_1'))
      expect(page).to have_css('h2#totp-step-4-label', text: t('forms.totp_setup.totp_step_4'))

      secret = find('#qr-code').text
      fill_in 'name', with: 'foo'
      fill_in 'code', with: generate_totp_code(secret)
      click_button t('forms.buttons.continue')

      expect(user.auth_app_configurations).to be_empty
      expect(user.events.order(created_at: :desc).last.event_type).to eq('authenticator_enabled')
    end

    it 'prevents association of an auth app with the same name' do
      sign_in_and_2fa_user(user)
      visit account_security_path

      click_link t('account.index.auth_app_add'), href: authenticator_setup_url

      secret = find('#qr-code').text
      fill_in 'name', with: 'foo'
      fill_in 'code', with: generate_totp_code(secret)
      click_button t('forms.buttons.continue')

      click_link t('account.index.auth_app_add'), href: authenticator_setup_url

      secret = find('#qr-code').text
      fill_in 'name', with: 'foo'
      fill_in 'code', with: generate_totp_code(secret)
      click_button t('forms.buttons.continue')

      expect(page).to have_current_path(authenticator_setup_path)
      expect(page).to have_content(I18n.t('errors.piv_cac_setup.unique_name'))
    end

    it 'allows 2 auth apps and removes the add link' do
      sign_in_and_2fa_user(user)
      visit account_security_path

      click_link t('account.index.auth_app_add'), href: authenticator_setup_url

      secret = find('#qr-code').text
      fill_in 'name', with: 'foo'
      fill_in 'code', with: generate_totp_code(secret)
      click_button t('forms.buttons.continue')

      # simulate user delay. totp has a 30 second time step
      travel_to(30.seconds.from_now) do
        click_link t('account.index.auth_app_add'), href: authenticator_setup_url

        secret = find('#qr-code').text
        fill_in 'name', with: 'bar'
        fill_in 'code', with: generate_totp_code(secret)
        click_button t('forms.buttons.continue')

        expect(page).to have_current_path(account_security_path)
        expect(user.auth_app_configurations.count).to eq(2)
        expect(page)
          .to_not have_link(t('account.index.auth_app_add'), href: authenticator_setup_url)
      end
    end
  end
end
