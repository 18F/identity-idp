require 'rails_helper'

RSpec.describe 'users/backup_code_setup/confirm_delete.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('forms.backup_code.confirm_delete'))

    render
  end

  context 'in the default layout' do
    it 'renders the legacy heading and caution copy' do
      render

      expect(rendered).to have_css('h1', text: t('forms.backup_code.confirm_delete'))
      expect(rendered).to have_content(t('forms.backup_code.caution_delete'))
    end

    it 'submits the delete form and links to cancel' do
      render

      expect(rendered).to have_css(
        "form[action='#{backup_code_delete_path}'] [name=_method][value=delete]",
        visible: :all,
      )
      expect(rendered).to have_button(t('account.index.backup_code_confirm_delete'))
      expect(rendered).to have_link(t('links.cancel'), href: account_path)
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

    it 'renders the form-page card with the confirm-delete heading' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('forms.backup_code.confirm_delete'),
      )
    end

    it 'renders the warning status icon' do
      render

      expect(rendered).to have_selector('.nds-status-icon.nds-status-icon--warning .usa-icon')
    end

    it 'renders the caution copy and a divider' do
      render

      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
      expect(rendered).to have_content(t('forms.backup_code.caution_delete'))
    end

    it 'renders the delete submit button posting to the backup code delete path' do
      render

      expect(rendered).to have_css(
        "form[action='#{backup_code_delete_path}'] [name=_method][value=delete]",
        visible: :all,
      )
      expect(rendered).to have_button(t('account.index.backup_code_confirm_delete'))
    end

    it 'renders the cancel button linking to the account path' do
      render

      expect(rendered).to have_link(t('links.cancel'), href: account_path)
    end
  end
end
