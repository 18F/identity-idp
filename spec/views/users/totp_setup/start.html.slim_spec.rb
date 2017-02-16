require 'rails_helper'

describe 'users/totp_setup/start.html.slim' do
  let(:user) { build_stubbed(:user) }

  before do
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.totp_setup.start'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_selector('h1', text: t('headings.totp_setup.start'))
  end

  it 'contains link to totp qr code page' do
    render

    expect(rendered).to have_link(t('forms.buttons.setup_totp'), \
                                  href: authenticator_setup_url)
  end
end
