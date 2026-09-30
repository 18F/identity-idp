require 'rails_helper'

RSpec.describe 'users/backup_code_setup/new.html.erb' do
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(
      t('two_factor_authentication.confirm_backup_code_setup_title'),
    )

    render
  end

  it 'has a localized heading' do
    render

    expect(rendered).to have_css(
      'h1',
      text: t('two_factor_authentication.confirm_backup_code_setup_title'),
    )
  end

  it 'has a button to continue' do
    render

    expect(rendered).to have_css(
      "form[method=post][action='#{backup_code_setup_path}']:not(:has([name=_method]))",
      text: t('forms.buttons.continue'),
    )
  end

  it 'has a link to cancel' do
    render

    expect(rendered).to have_link(t('links.cancel'), href: account_path)
  end

  context 'with account redirect path session value' do
    let(:account_redirect_path) { account_two_factor_authentication_path }

    before do
      session[:account_redirect_path] = account_redirect_path
    end

    it 'has a link to cancel and return to account redirect path' do
      render

      expect(rendered).to have_link(t('links.cancel'), href: account_redirect_path)
    end
  end

  it 'does not render the NDS form-page card in the default layout' do
    render

    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the heading and intro paragraphs' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('two_factor_authentication.confirm_backup_code_setup_title'),
      )
      paragraphs = t(
        'two_factor_authentication.confirm_backup_code_setup_content_html',
        number_of_codes: BackupCodeGenerator::NUMBER_OF_CODES,
      )
      expect(rendered).to have_css('.auth__form-page-body .copy p', count: paragraphs.size)
    end

    it 'renders a primary continue submit above a secondary cancel' do
      render

      expect(rendered).to have_css(
        ".auth__actions .actions form[method=post][action='#{backup_code_setup_path}']",
      )
      expect(rendered).to_not have_css('.auth__actions form [name=_method]', visible: :all)
      expect(rendered).to have_css(
        '.auth__actions .actions form button.usa-button:not(.usa-button--secondary)',
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to have_css(
        ".auth__actions .actions a.usa-button--secondary[href='#{account_path}']",
        text: t('links.cancel'),
      )
    end

    context 'with account redirect path session value' do
      before { session[:account_redirect_path] = account_two_factor_authentication_path }

      it 'points the cancel button at the account redirect path' do
        render

        expect(rendered).to have_link(
          t('links.cancel'),
          href: account_two_factor_authentication_path,
          class: 'usa-button--secondary',
        )
      end
    end
  end
end
