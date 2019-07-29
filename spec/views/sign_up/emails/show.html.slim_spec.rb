require 'rails_helper'

describe 'sign_up/emails/show.html.slim' do
  before do
    allow(view).to receive(:email).and_return('foo@bar.com')
    @register_user_email_form = RegisterUserEmailForm.new
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.verify_email'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_selector('h1', text: t('headings.verify_email'))
  end

  it 'contains link to resend confirmation page' do
    render

    expect(rendered).to have_button(t('links.resend'))
  end
end
