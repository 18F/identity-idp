require 'rails_helper'

describe 'two_factor_authentication/reset_device/show.html.slim' do
  let(:user) { build_stubbed(:user, :signed_up) }

  before do
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'has a localized heading' do
    render

    expect(rendered).
      to have_content t('devise.two_factor_authentication.reset_device.header_text')
  end

  it 'has a button with the same localized heading' do
    render

    expect(rendered).to have_xpath("//input[@value='#{t('devise.two_factor_authentication.reset_device.header_text')}']")
  end

  it 'has a cancel link' do
    render

    expect(rendered).
        to have_link(t('links.cancel'), href: sign_out_path)
  end
end
