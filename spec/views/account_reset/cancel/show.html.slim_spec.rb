require 'rails_helper'

describe 'account_reset/cancel/show.html.slim' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('account_reset.cancel_request.title'))

    render
  end

  it 'has button to cancel request' do
    render
    expect(rendered).to have_button t('account_reset.cancel_request.cancel_button')
  end
end
