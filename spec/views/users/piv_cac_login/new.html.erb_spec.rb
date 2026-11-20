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

  it 'does not render the NDS agency seal in the default layout' do
    allow(view).to receive(:current_sp)
      .and_return(build_stubbed(:service_provider, logo: 'DOS.svg'))
    render

    expect(rendered).not_to have_css('.agency-seal')
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
      allow(view).to receive(:current_sp).and_return(nil)
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

    it 'renders no agency seal without a service provider' do
      render

      expect(rendered).not_to have_css('.agency-seal')
    end

    context 'with a service provider logo' do
      let(:sp) do
        build_stubbed(:service_provider, friendly_name: 'Veterans Affairs', logo: 'DOS.svg')
      end

      before do
        allow(view).to receive(:current_sp).and_return(sp)
        allow(view).to receive(:decorated_sp_session).and_return(
          ServiceProviderSessionCreator.new(
            sp:,
            view_context: ActionController::Base.new.view_context,
            sp_session: {},
            service_provider_request: ServiceProviderRequest.new,
          ).create_session,
        )
      end

      it 'renders the 100px agency seal, named for the SP, above the heading' do
        seal_selector = '.auth__header--with-media img.agency-seal.agency-seal--100'
        render

        expect(rendered).to have_css(
          "#{seal_selector}[alt='Veterans Affairs'][src='#{sp.logo_url}']",
        )
      end
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
