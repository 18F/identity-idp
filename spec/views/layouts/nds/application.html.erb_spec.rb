require 'rails_helper'

RSpec.describe 'layouts/nds/application.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:current_sp) { nil }
  let(:sp_name) { nil }

  before do
    allow(view).to receive(:nds_layout?).and_return(true)
    allow(view).to receive(:current_sp).and_return(current_sp)
    allow(view).to receive(:decorated_sp_session)
      .and_return(instance_double(ServiceProviderSession, sp_name:))
    allow(view).to receive(:user_fully_authenticated?).and_return(false)
    allow(view.request).to receive(:original_fullpath).and_return('/foobar')
    allow(view).to receive(:url_for).and_return('/')
    view.title = 'Example'
  end

  it 'renders the header without agency co-branding when no SP is in session' do
    render

    expect(rendered).to have_css('header.auth-page__top-chrome .auth-page__logo-banner')
    expect(rendered).not_to have_css('.auth-page__logo-banner-agency')
  end

  context 'with a service provider logo in session' do
    let(:current_sp) { build(:service_provider, logo: 'DOS.svg') }
    let(:sp_name) { 'Department of State' }

    it 'co-brands the header with the 24px agency seal named for the SP' do
      seal_selector = '.auth-page__logo-banner-agency img.agency-seal.agency-seal--24'
      render

      expect(rendered).to have_css(
        "#{seal_selector}[alt='Department of State'][src='#{current_sp.logo_url}']",
      )
    end

    it 'keeps the agency seal next to the progress stepper' do
      view.content_for(:nds_header_progress, 'STEPPER')
      render

      expect(rendered).to have_css('.auth-page__logo-banner-agency .agency-seal')
      expect(rendered).to have_css('.auth-page__top-chrome-progress', text: 'STEPPER')
    end

    it 'leaves the agency out of the header on auth-entry pages' do
      view.content_for(:nds_auth_entry, 'true')
      render

      expect(rendered).to have_css('.auth-page__logo-banner')
      expect(rendered).not_to have_css('.auth-page__logo-banner-agency')
    end
  end

  context 'with a service provider without a logo' do
    let(:current_sp) { build(:service_provider, logo: nil) }
    let(:sp_name) { 'Test Service Provider' }

    it 'renders no agency co-branding' do
      render

      expect(rendered).not_to have_css('.auth-page__logo-banner-agency')
    end
  end
end
