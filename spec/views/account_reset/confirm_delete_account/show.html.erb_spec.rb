require 'rails_helper'

describe 'account_reset/confirm_delete_account/show.html.erb' do
  before do
    allow(view).to receive(:email).and_return('foo@bar.com')
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('account_reset.confirm_delete_account.title'))

    render
  end

  it 'contains the user email' do
    email = 'foo@bar.com'
    session[:email] = email

    render

    expect(rendered).to have_content(email)
  end

  it 'contains link to create a new account' do
    render

    expect(rendered).to have_link(
      t('account_reset.confirm_delete_account.link_text', app_name: APP_NAME),
      href: sign_up_email_path,
    )
  end
end
