require 'rails_helper'

RSpec.describe 'users/backup_code_setup/edit.html.erb' do
  subject(:rendered) { render }

  it 'has a button to confirm and proceed to setup' do
    expect(rendered).to have_css(
      "form[method=post][action='#{backup_code_setup_path}']:not(:has([name=_method]))",
      text: t('account.index.backup_code_confirm_regenerate'),
    )
  end

  it 'has a link to cancel and return to account page' do
    expect(rendered).to have_link(t('links.cancel'), href: account_path)
  end
end
