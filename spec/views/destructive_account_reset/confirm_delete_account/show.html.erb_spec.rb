require 'rails_helper'

RSpec.describe 'destructive_account_reset/confirm_delete_account/show.html.erb' do
  let(:email) { 'foo@bar.com' }

  before do
    allow(view).to receive(:email).and_return(email)
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(
      t('destructive_account_reset.confirm_delete_account.title'),
    )

    render
  end

  it 'contains the user email' do
    session[:email] = email

    render

    expect(rendered).to have_content(email)
  end

  it 'contains link to create a new account' do
    render

    expect(rendered).to have_link(
      t('destructive_account_reset.confirm_delete_account.link_text', app_name: APP_NAME),
      href: sign_up_email_path,
    )
  end

  it 'does not render the NDS form-page card' do
    render
    expect(rendered).not_to have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'renders the error badge and account deleted heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth__header .nds-status-icon.nds-status-icon--error')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro h1',
        text: t('nds.destructive_account_reset.confirm_delete_account.heading'),
      )
    end

    it 'renders the divider and the deleted email' do
      expect(rendered).to have_css('.auth__form-page-body hr.divider')
      expect(rendered).to have_css('.auth__form-page-body p strong', text: email)
    end

    it 'links to create a new account from the primary action' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{sign_up_email_path}']",
        text: t('nds.destructive_account_reset.confirm_delete_account.create_account'),
      )
    end
  end
end
