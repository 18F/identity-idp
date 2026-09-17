require 'rails_helper'

RSpec.describe 'users/backup_code_setup/confirm_backup_codes.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.backup_codes'))

    render
  end

  context 'in the default layout' do
    it 'renders the legacy heading and copy' do
      render

      expect(rendered).to have_css('h1', text: t('titles.backup_codes'))
      expect(rendered).to have_content(
        t('two_factor_authentication.backup_codes.instructions', app_name: APP_NAME),
      )
    end

    it 'renders the add-another-method link and the continue submit in the footer' do
      render

      expect(rendered).to have_link(t('mfa.add'), href: authentication_methods_setup_path)
      expect(rendered).to have_css(
        ".page-footer form[action='#{auth_method_confirmation_skip_path}'][method=post]",
      )
      expect(rendered).to have_button(t('forms.buttons.continue'))
    end

    it 'does not render the NDS form-page card' do
      render

      expect(rendered).to_not have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the backup codes heading and copy' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('.auth--form-page h1', text: t('titles.backup_codes'))
      expect(rendered).to have_selector(
        '.auth__form-page-body .copy p',
        text: t('two_factor_authentication.backup_codes.instructions', app_name: APP_NAME),
      )
    end

    it 'renders the add-another-method primary button above a secondary continue submit' do
      render

      expect(rendered).to have_css(
        ".auth__actions .actions a.usa-button[href='#{authentication_methods_setup_path}']",
        text: t('mfa.add'),
      )
      expect(rendered).to have_css(
        ".auth__actions .actions form[action='#{auth_method_confirmation_skip_path}'][method=post]",
      )
      expect(rendered).to have_css(
        '.auth__actions .actions form button.usa-button.usa-button--secondary',
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to have_css('.actions > a + form')
    end

    it 'does not render a divider above the actions' do
      render

      expect(rendered).to_not have_selector('hr.divider')
      expect(rendered).to_not have_selector('.page-footer')
    end
  end
end
