require 'rails_helper'

RSpec.feature 'NDS account Security tab' do
  let(:user) { create(:user, :fully_registered, :with_backup_code) }

  before do
    allow(IdentityConfig.store).to receive(:ui_test_bucket_params_enabled).and_return(true)
  end

  def visit_security_tab
    sign_in_and_2fa_user(user)
    visit account_two_factor_authentication_path(ui_test_bucket: 'nds')
    expect(page).to have_css('.account-shell .auth-methods')
  end

  def manage_label(prefix_key, name)
    [t(prefix_key), name].join(': ')
  end

  scenario 'without javascript, Manage opens the manage page' do
    configuration = create(:webauthn_configuration, user:)

    visit_security_tab
    click_link manage_label(
      'two_factor_authentication.webauthn_roaming.manage_accessible_label',
      configuration.name,
    )

    expect(page).to have_current_path(edit_webauthn_path(id: configuration.id))
  end

  scenario 'deleting backup codes returns to the account with the flash in the shell' do
    visit_security_tab
    click_link t('forms.buttons.delete'), href: backup_code_delete_path
    click_button t('account.index.backup_code_confirm_delete')

    expect(page).to have_css('.account-shell__flash', text: t('notices.backup_codes_deleted'))
    expect(user.reload.backup_code_configurations).to be_empty
  end

  # The NDS layout's session timeout ping logs a querySelectorAll TypeError on main.
  context 'with javascript enabled', :js, allow_browser_log: true do
    scenario 'renaming a security key in place' do
      configuration = create(:webauthn_configuration, user:)

      visit_security_tab
      click_button manage_label(
        'two_factor_authentication.webauthn_roaming.manage_accessible_label',
        configuration.name,
      )

      expect(page).to have_field(
        t('nds.dashboard_security.webauthn_nickname'),
        with: configuration.name,
      )
      expect(page).not_to have_css('.auth-methods__row-text', text: configuration.name)
      fill_in t('nds.dashboard_security.webauthn_nickname'), with: 'new name'
      click_button t('components.manageable_authenticator.save')

      expect(page).to have_content(t('two_factor_authentication.webauthn_roaming.renamed'), wait: 5)
      expect(page).not_to have_field(t('nds.dashboard_security.webauthn_nickname'))
      expect(page).to have_css('.auth-methods__row-text', text: 'new name')
      expect(configuration.reload.name).to eq('new name')
    end

    scenario 'deleting a passkey in place' do
      configuration = create(:webauthn_configuration, :platform_authenticator, user:)

      visit_security_tab
      click_button manage_label(
        'two_factor_authentication.webauthn_platform.manage_accessible_label',
        configuration.name,
      )
      accept_confirm(wait: 5) { click_button t('components.manageable_authenticator.delete') }

      expect(page).to have_content(
        t('two_factor_authentication.webauthn_platform.deleted'),
        wait: 5,
      )
      expect(page).not_to have_content(configuration.name)
      expect(user.reload.webauthn_configurations).to be_empty
    end
  end
end
