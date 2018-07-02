require 'rails_helper'

describe 'account_reset/confirm_request/show.html.slim' do
  before do
    allow(view).to receive(:email).and_return('foo@bar.com')
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('account_reset.confirm_request.check_your_email'))

    render
  end

  it 'contains the user email' do
    email = 'foo@bar.com'
    session[:email] = email

    render

    expect(rendered).to have_content(email)
  end
end
