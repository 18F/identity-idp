require 'rails_helper'

RSpec.describe 'users/backup_code_setup/new.html.erb' do
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
end
