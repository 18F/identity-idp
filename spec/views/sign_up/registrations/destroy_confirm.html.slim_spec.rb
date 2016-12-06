require 'rails_helper'

describe 'sign_up/registrations/destroy_confirm.html.slim' do
  before do
    user = build_stubbed(:user, :signed_up)
    allow(view).to receive(:current_user).and_return(user)
  end

  xit 'has a localized title' do
    pending 'temporarily disabled until we figure out the MBUN to SSN mapping'

    expect(view).to receive(:title).with(t('titles.registrations.destroy_confirm'))

    render
  end

  xit 'contains link to delete account' do
    pending 'temporarily disabled until we figure out the MBUN to SSN mapping'

    render

    expect(rendered).to have_content t('devise.registrations.destroy_confirm')

    expect(rendered).
      to have_xpath("//input[@value='#{t('forms.buttons.delete_account_confirm')}']")
  end
end
