require 'rails_helper'

describe 'users/totp_setup/new.html.slim' do
  let(:user) { build_stubbed(:user, :signed_up) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    @qrcode = 'qrcode.png'
  end

  it 'renders the QR code image' do
    render

    expect(rendered).to have_css('img[src^="/images/qrcode.png"]')
  end
end
