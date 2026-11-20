require 'rails_helper'

RSpec.describe NDS::PageChromeComponent, type: :component do
  before do
    allow_any_instance_of(BaseComponent).to receive(:nds_bucket?).and_return(true)
  end

  it 'renders the top-chrome header with the gov banner and logo banner' do
    rendered = render_inline(NDS::PageChromeComponent.new)
    expect(rendered).to have_css('header.auth-page__top-chrome')
    expect(rendered).to have_css('.auth-page__logo-banner .auth-page__logo-banner-link')
    expect(rendered).to have_css('.auth-page__logo-banner-image')
  end

  it 'hides the logo when hide_logo: true' do
    rendered = render_inline(NDS::PageChromeComponent.new(hide_logo: true))
    expect(rendered).to have_css('header.auth-page__top-chrome')
    expect(rendered).not_to have_css('.auth-page__logo-banner')
  end

  it 'renders no agency co-branding by default' do
    rendered = render_inline(NDS::PageChromeComponent.new)
    expect(rendered).not_to have_css('.auth-page__logo-banner-agency')
    expect(rendered).not_to have_css('.agency-seal')
  end

  it 'co-brands the logo banner with a 24px agency seal after the logo' do
    rendered = render_inline(
      NDS::PageChromeComponent.new(
        agency_name: 'Department of State',
        agency_logo_url: '/sp-logos/DOS.svg',
      ),
    )
    expect(rendered).to have_css(
      '.auth-page__logo-banner .auth-page__logo-banner-link + .auth-page__logo-banner-agency',
    )
    expect(rendered).to have_css(
      '.auth-page__logo-banner-agency img.agency-seal.agency-seal--24' \
        '[src="/sp-logos/DOS.svg"][alt="Department of State"][width="24"][height="24"]',
    )
  end

  it 'renders the agency seal alongside the progress slot' do
    rendered = render_inline(
      NDS::PageChromeComponent.new(agency_name: 'VA', agency_logo_url: '/va.svg'),
    ) do |chrome|
      chrome.with_progress { 'PROGRESS' }
    end
    expect(rendered).to have_css('.auth-page__logo-banner-agency img[alt="VA"]')
    expect(rendered).to have_css('.auth-page__top-chrome-progress', text: 'PROGRESS')
  end

  it 'renders no agency seal without a logo URL' do
    rendered = render_inline(NDS::PageChromeComponent.new(agency_name: 'VA'))
    expect(rendered).not_to have_css('.auth-page__logo-banner-agency')
  end

  it 'renders no progress wrapper by default' do
    rendered = render_inline(NDS::PageChromeComponent.new)
    expect(rendered).not_to have_css('.auth-page__top-chrome-progress')
  end

  it 'renders a progress slot inside a progress wrapper' do
    rendered = render_inline(NDS::PageChromeComponent.new) do |chrome|
      chrome.with_progress { 'PROGRESS' }
    end
    expect(rendered).to have_css('.auth-page__top-chrome-progress', text: 'PROGRESS')
  end
end
