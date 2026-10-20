require 'rails_helper'

RSpec.describe 'destructive_account_reset/delete_account/show.html.erb' do
  before do
    allow(view).to receive(:email).and_return('foo@bar.com')
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('destructive_account_reset.delete_account.title'))

    render
  end

  it 'has button to delete' do
    render
    expect(rendered).to have_button t('destructive_account_reset.request.yes_continue')
  end
end
