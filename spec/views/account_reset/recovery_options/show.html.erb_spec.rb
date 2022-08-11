require 'rails_helper'

describe 'account_reset/recovery_options/show.html.erb' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('account_reset.recovery_options.header'))

    render
  end

  it 'has button to cancel request' do
    render
    expect(rendered).to have_button t('account_reset.request.no_cancel')
  end
end
