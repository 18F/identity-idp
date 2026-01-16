require 'rails_helper'

RSpec.describe 'account_reset/confirm_request/show.html.erb' do
  before do
    allow(view).to receive(:email).and_return('foo@bar.com')
    allow(view).to receive(:sms_phone).and_return(true)
    allow(view).to receive(:waiting_period).and_return('24 hours')
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.verify_email'))

    render
  end
end
