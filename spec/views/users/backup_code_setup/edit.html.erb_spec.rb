require 'rails_helper'

RSpec.describe 'users/backup_code_setup/edit.html.erb' do
  subject(:rendered) { render }

  it 'has a link to confirm and proceed to setup' do
    expect(rendered).to have_link(
      t('account.index.backup_code_confirm_regenerate'),
      href: backup_code_setup_path,
    )
  end

  it 'has a link to cancel and return to account page' do
    expect(rendered).to have_link(t('links.cancel'), href: account_path)
  end
end
