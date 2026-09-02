require 'rails_helper'

RSpec.describe 'users/piv_cac_login/new.html.erb' do
  let(:presenter) do
    instance_double(
      PivCacAuthenticationLoginPresenter,
      title: 'PIV/CAC title',
      heading: 'Sign in with your government employee ID',
      info: 'Make sure you have a Login.gov account.',
      piv_cac_service_link: '/account/login/present_piv_cac',
      piv_cac_capture_text: 'Insert PIV/CAC',
    )
  end

  before do
    assign(:presenter, presenter)
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:user_signing_up?).and_return(false)
  end

  it 'renders the legacy heading, info, and capture button' do
    render

    expect(rendered).to have_content('Sign in with your government employee ID')
    expect(rendered).to have_content('Make sure you have a Login.gov account.')
    expect(rendered).to have_link(
      'Insert PIV/CAC',
      href: '/account/login/present_piv_cac',
    )
  end

  context 'nds bucket' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the NDS auth-entry PIV/CAC card' do
      render

      expect(rendered).to have_css('.auth-entry .auth-entry__card section.auth.auth--form-page')
      expect(rendered).to have_css('h1', text: 'Sign in with your government employee ID')
      expect(rendered).to have_content('Make sure you have a Login.gov account.')
    end

    it 'renders the full-width primary capture button' do
      render

      expect(rendered).to have_css(
        '.auth__actions a.usa-button',
        text: 'Insert PIV/CAC',
      )
      expect(rendered).to have_link(
        'Insert PIV/CAC',
        href: '/account/login/present_piv_cac',
      )
    end

    it 'renders an icon-only back affordance linking to sign in' do
      render

      expect(rendered).to have_css(
        'a.auth-entry__back.usa-button--icon-only[aria-label="Back"]',
      )
      expect(rendered).to have_css('a.auth-entry__back svg.usa-icon')
      expect(rendered).to have_link(nil, href: new_user_session_url)
    end
  end
end
