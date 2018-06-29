require 'rails_helper'

describe 'account_reset/request/show.html.slim' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('account_reset.request.title'))

    render
  end

  it 'has button to delete' do

    render
    expect(rendered).to have_button t('account_reset.request.yes_continue')
  end
end
