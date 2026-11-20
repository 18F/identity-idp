require 'rails_helper'

RSpec.describe NDS::AccountHeaderComponent, type: :component do
  let(:user) { create(:user, :fully_registered, email: 'header@example.com') }
  let(:current) { nil }
  let(:routes) { Rails.application.routes.url_helpers }

  subject(:rendered) { render_inline(described_class.new(user:, current:)) }

  before do
    # button_to needs a CSRF token outside a real request.
    allow_any_instance_of(ActionView::Base).to receive(:protect_against_forgery?)
      .and_return(false)
  end

  it 'renders the gov banner above the account header' do
    expect(rendered).to have_css('.official-banner')
    expect(rendered).to have_css('header.account-header')
    html = rendered.to_html
    expect(html.index('official-banner')).to be < html.index('account-header')
  end

  it 'links the logo home' do
    expect(rendered).to have_css(
      "a.account-header__logo-link[href='#{routes.root_path}'][aria-label='#{APP_NAME}']",
    )
    expect(rendered).to have_css('img.account-header__logo[alt=""]')
  end

  it 'renders the email menu with the signed-in email and a sign out button' do
    summary = rendered.at_css('details.account-header__menu > summary.account-header__menu-button')

    expect(summary).to be_present
    expect(summary.at_css('.account-header__menu-email').text).to eq('header@example.com')
    expect(summary.at_css('.usa-sr-only').text).to eq(t('nds.account_nav.account_menu'))
    expect(summary).to have_css('svg.account-header__menu-chevron')
    expect(rendered).to have_css(
      ".account-header__menu form.account-mobile-menu__logout-form[action='#{routes.logout_path}']",
      visible: :all,
    )
    expect(rendered).to have_css(
      '.account-header__menu form input[name="_method"][value="delete"]',
      visible: :all,
    )
    expect(rendered).to have_css(
      '.account-header__menu button.account-mobile-menu__logout-button',
      text: t('links.sign_out'),
      visible: :all,
    )
  end

  it 'renders the mobile menu with the account navigation and a sign out button' do
    summary = rendered.at_css('details.account-mobile-menu > summary.account-mobile-menu__summary')

    expect(summary).to be_present
    expect(summary.at_css('.usa-sr-only').text).to eq(t('account.navigation.menu'))
    expect(rendered).to have_css(
      '.account-mobile-menu .account-mobile-menu__panel nav.account-nav.account-nav--mobile',
      visible: :all,
    )
    expect(rendered).to have_css(
      ".account-mobile-menu__logout form[action='#{routes.logout_path}'] button",
      text: t('links.sign_out'),
      visible: :all,
    )
  end

  context 'with a current navigation item' do
    let(:current) { 'security' }

    it 'marks it in the mobile menu' do
      expect(rendered).to have_css(
        '.account-mobile-menu .account-nav__link--current',
        text: t('nds.account_nav.security'),
        visible: :all,
      )
    end
  end
end
