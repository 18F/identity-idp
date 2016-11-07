require 'rails_helper'

describe 'users/registrations/verify_email.html.slim' do
  before do
    allow(view).to receive(:email).and_return('foo@bar.com')
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.registrations.verify_email'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_selector('h1', text: t('headings.registrations.verify_email'))
  end

  it 'contains link to resend confirmation page' do
    render

    expect(rendered).to have_link(t('links.resend'), href: new_user_confirmation_path)
  end
end
