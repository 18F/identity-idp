require 'rails_helper'

RSpec.describe 'account_reset/request/show.html.erb' do
  before do
    user = create(:user, :fully_registered, :with_personal_key)
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('account_reset.request.title'))

    render
  end

  it 'has button to delete' do
    render
    expect(rendered).to have_button t('account_reset.request.yes_continue')
  end
end
