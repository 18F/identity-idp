require 'rails_helper'

describe 'devise/registrations/destroy_confirm.html.slim' do
  before do
    user = build_stubbed(:user, :signed_up)
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.registrations.destroy_confirm'))

    render
  end

  it 'contains link to delete account' do
    render

    expect(rendered).to have_content t('devise.registrations.destroy_confirm')

    expect(rendered).
      to have_xpath("//input[@value='#{t('forms.buttons.delete_account_confirm')}']")
  end
end
