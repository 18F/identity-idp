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

  it 'renders a progress slot inside a progress wrapper' do
    rendered = render_inline(NDS::PageChromeComponent.new) do |chrome|
      chrome.with_progress { 'PROGRESS' }
    end
    expect(rendered).to have_css('.auth-page__top-chrome-progress', text: 'PROGRESS')
  end
end
