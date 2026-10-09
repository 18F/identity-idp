require 'rails_helper'

RSpec.describe 'users/backup_code_setup/edit.html.erb' do
  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a button to confirm and proceed to setup' do
    expect(rendered).to have_css(
      "form[method=post][action='#{backup_code_setup_path}']:not(:has([name=_method]))",
      text: t('account.index.backup_code_confirm_regenerate'),
    )
  end

  it 'has a link to cancel and return to account page' do
    expect(rendered).to have_link(t('links.cancel'), href: account_path)
  end

  it 'does not render the NDS form-page card in the default layout' do
    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the warning icon, heading, divider and caution' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('.nds-status-icon.nds-status-icon--warning .usa-icon')
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('forms.backup_code_regenerate.confirm'),
      )
      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
      expect(rendered).to have_content(t('forms.backup_code_regenerate.caution'))
    end

    it 'renders the primary regenerate submit above a secondary cancel' do
      expect(rendered).to have_css(
        ".auth__actions .actions form[method=post][action='#{backup_code_setup_path}']",
      )
      expect(rendered).to_not have_css('.auth__actions form [name=_method]', visible: :all)
      expect(rendered).to have_css(
        '.auth__actions .actions form button.usa-button:not(.usa-button--secondary)',
        text: t('account.index.backup_code_confirm_regenerate'),
      )
      expect(rendered).to have_css(
        ".auth__actions .actions a.usa-button--secondary[href='#{account_path}']",
        text: t('links.cancel'),
      )
    end
  end
end
