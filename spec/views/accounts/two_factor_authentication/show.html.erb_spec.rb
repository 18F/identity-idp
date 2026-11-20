require 'rails_helper'

RSpec.describe 'accounts/two_factor_authentication/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_personal_key) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    assign(
      :presenter,
      AccountShowPresenter.new(
        decrypted_pii: nil,
        user: user,
        sp_session_request_url: nil,
        authn_context: nil,
        sp_name: nil,
        locked_for_session: false,
      ),
    )
  end

  context 'user is not TOTP enabled' do
    it 'contains link to enable TOTP' do
      render

      expect(rendered).to have_link(t('account.index.auth_app_add'), href: authenticator_setup_url)
      expect(rendered).not_to have_link(t('forms.buttons.disable'))
    end
  end

  context 'when user is TOTP enabled' do
    let(:user) { create(:user, :fully_registered, :with_authentication_app) }

    before do
      assign(
        :presenter,
        AccountShowPresenter.new(
          decrypted_pii: nil,
          user: user,
          sp_session_request_url: nil,
          authn_context: nil,
          sp_name: nil,
          locked_for_session: false,
        ),
      )
    end
  end

  context 'when the user does not have password_reset_profile' do
    before do
      allow(user).to receive(:password_reset_profile).and_return(false)
    end

    it 'contains a personal key section' do
      render

      expect(rendered).to have_content t('account.items.personal_key')
      expect(rendered).to have_link(
        t('account.links.regenerate_personal_key'),
        href: create_new_personal_key_url,
      )
    end
  end

  context 'when current user has password_reset_profile' do
    before do
      allow(user).to receive(:password_reset_profile).and_return(true)
    end

    it 'lacks a personal key section' do
      render

      expect(rendered).to_not have_content t('account.items.personal_key')
      expect(rendered).to_not have_link(
        t('account.links.regenerate_personal_key'), href: manage_personal_key_path
      )
    end
  end

  it 'does not render the NDS authentication methods in the default layout' do
    render

    expect(rendered).not_to have_css('.auth-methods')
    expect(rendered).to have_css('.card')
  end

  context 'in the NDS layout' do
    let(:user) do
      create(
        :user,
        :fully_registered,
        :with_personal_key,
        :with_authentication_app,
        :with_piv_or_cac,
        :with_backup_code,
      )
    end
    let(:platform_configuration) do
      create(:webauthn_configuration, :platform_authenticator, user:, name: 'Safari on macOS')
    end
    let(:roaming_configuration) { create(:webauthn_configuration, user:, name: 'YubiKey') }

    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      allow(view).to receive(:user_session).and_return({})
      platform_configuration
      roaming_configuration
      user.reload
      assign(
        :presenter,
        AccountShowPresenter.new(
          decrypted_pii: nil,
          user: user,
          sp_session_request_url: nil,
          authn_context: nil,
          sp_name: nil,
          locked_for_session: false,
        ),
      )
    end

    def section(heading)
      find_section = Capybara.string(rendered).find('.auth-methods__section', text: heading)
      expect(find_section).to have_css('h2.auth-methods__heading', exact_text: heading)
      find_section
    end

    it 'renders one visually hidden page heading and the Figma sections in order' do
      render

      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css('h1.usa-sr-only', text: t('headings.account.two_factor'))
      expect(rendered).not_to have_css('.card')
      expect(Capybara.string(rendered).all('h2.auth-methods__heading').map(&:text)).to eq(
        [
          t('nds.mfa_setup.options.webauthn_platform'),
          t('nds.mfa_setup.options.auth_app'),
          t('account.index.backup_codes'),
          t('account.index.webauthn'),
          t('headings.account.government_employee_id'),
        ],
      )
    end

    it 'leaves the phone and personal key sections to the Account tab' do
      render

      expect(rendered).not_to have_content(t('account.index.phone'))
      expect(rendered).not_to have_content(t('account.items.personal_key'))
    end

    it 'renders each passkey as a manageable row with an inline nickname field' do
      render

      passkeys = section(t('nds.mfa_setup.options.webauthn_platform'))
      authenticator = passkeys.find('lg-manageable-authenticator[inline-rename]')
      expect(authenticator['role']).to eq('listitem')
      expect(authenticator['api-url']).to eq(
        api_internal_two_factor_authentication_webauthn_path(id: platform_configuration.id),
      )
      expect(passkeys).to have_css(
        '.auth-methods__row-text',
        text: 'Safari on macOS',
      )
      expect(passkeys).to have_content(
        t(
          'components.manageable_authenticator.created_on',
          date: l(platform_configuration.created_at, format: :event_date),
        ),
      )
      expect(passkeys).to have_link(
        href: edit_webauthn_path(id: platform_configuration.id),
        class: 'no-js',
      )
      expect(passkeys).to have_field(
        t('nds.dashboard_security.webauthn_platform_nickname'),
        with: 'Safari on macOS',
        visible: :all,
      )
      expect(passkeys).to have_link(
        t('nds.webauthn_platform_recommended.cta'),
        href: webauthn_setup_path(platform: true),
        class: 'usa-button--secondary',
      )
      expect(passkeys).not_to have_content('YubiKey')
    end

    it 'renders authentication apps with their add button' do
      render

      apps = section(t('nds.mfa_setup.options.auth_app'))
      configuration = user.auth_app_configurations.first
      expect(apps).to have_css('lg-manageable-authenticator', count: 1)
      expect(apps).to have_link(href: edit_auth_app_path(id: configuration.id), class: 'no-js')
      expect(apps).to have_field(
        t('nds.totp_setup.new.nickname_label'),
        with: configuration.name,
        visible: :all,
      )
      expect(apps).to have_link(t('account.index.auth_app_add'), href: authenticator_setup_url)
    end

    it 'hides the add app button at the authentication app limit' do
      allow(IdentityConfig.store).to receive(:max_auth_apps_per_account).and_return(1)

      render

      expect(section(t('nds.mfa_setup.options.auth_app')))
        .not_to have_link(t('account.index.auth_app_add'))
    end

    it 'renders security keys with the Figma add key button' do
      render

      keys = section(t('account.index.webauthn'))
      expect(keys).to have_css('.auth-methods__row-text', text: 'YubiKey')
      expect(keys).to have_link(
        href: edit_webauthn_path(id: roaming_configuration.id),
        class: 'no-js',
      )
      expect(keys).to have_field(
        t('nds.dashboard_security.webauthn_nickname'),
        with: 'YubiKey',
        visible: :all,
      )
      expect(keys).to have_link(t('nds.dashboard_security.webauthn_add'), href: webauthn_setup_path)
      expect(keys).not_to have_content(
        t('two_factor_authentication.two_factor_choice_options.webauthn_info'),
      )
    end

    it 'renders government employee IDs with the date they were added' do
      render

      ids = section(t('headings.account.government_employee_id'))
      configuration = user.piv_cac_configurations.first
      expect(ids).to have_content(
        t(
          'nds.dashboard_security.piv_cac_added_on',
          date: l(configuration.created_at, format: :event_date),
        ),
      )
      expect(ids).to have_link(href: edit_piv_cac_path(id: configuration.id), class: 'no-js')
      expect(ids).to have_field(t('nds.piv_cac_setup.nickname'), visible: :all)
      expect(ids).to have_link(t('account.index.piv_cac_add'), href: setup_piv_cac_url)
    end

    it 'hides the add ID button at the government employee ID limit' do
      allow(IdentityConfig.store).to receive(:max_piv_cac_per_account).and_return(1)

      render

      expect(section(t('headings.account.government_employee_id')))
        .not_to have_link(t('account.index.piv_cac_add'))
    end

    it 'renders backup codes with delete and regenerate actions' do
      render

      codes = section(t('account.index.backup_codes'))
      expect(codes).to have_css(
        '.auth-methods__row-text',
        text: t('account.index.backup_codes_exist'),
      )
      expect(codes).to have_css('lg-time')
      expect(codes).to have_link(
        t('forms.buttons.delete'),
        href: backup_code_delete_path,
        class: 'usa-button--tertiary',
      )
      expect(codes).to have_link(
        t('forms.backup_code.regenerate'),
        href: backup_code_regenerate_path,
        class: 'usa-button--secondary',
      )
    end

    context 'when the user has only one authentication method' do
      let(:user) { create(:user, :with_backup_code) }
      let(:platform_configuration) { nil }
      let(:roaming_configuration) { nil }

      it 'does not offer to delete the backup codes' do
        render

        codes = section(t('account.index.backup_codes'))
        expect(codes).to have_link(t('forms.backup_code.regenerate'))
        expect(codes).not_to have_link(t('forms.buttons.delete'))
      end
    end

    context 'when the user has no methods beyond a phone' do
      let(:user) { create(:user, :fully_registered) }
      let(:platform_configuration) { nil }
      let(:roaming_configuration) { nil }

      it 'renders each section with only its add button' do
        render

        expect(rendered).not_to have_css('lg-manageable-authenticator')
        expect(rendered).not_to have_css('[role="list"]')
        expect(rendered).to have_link(
          t('nds.webauthn_platform_recommended.cta'),
          href: webauthn_setup_path(platform: true),
        )
        expect(rendered).to have_link(t('nds.dashboard_security.webauthn_add'))
        codes = section(t('account.index.backup_codes'))
        expect(codes).to have_content(t('account.index.backup_codes_no_exist'))
        expect(codes).to have_link(t('forms.backup_code.generate'), href: backup_code_setup_path)
      end
    end
  end
end
