require 'rails_helper'

RSpec.describe 'layouts/nds/account_side_nav.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user, :fully_registered, email: 'shell@example.com') }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
    allow(view).to receive(:decorated_sp_session).and_return(
      ServiceProviderSessionCreator.new(
        sp: nil,
        view_context: nil,
        sp_session: {},
        service_provider_request: ServiceProviderRequestProxy.new,
      ).create_session,
    )
    allow(view.request).to receive(:original_fullpath).and_return('/account')
    view.title = 'Account'
    view.view_flow.set(:layout, '<h1>Page body</h1>'.html_safe)
  end

  it 'renders the NDS stylesheet, not the legacy one' do
    render

    expect(rendered).to have_css('link[href*="nds_application"]', visible: :all)
    expect(rendered).not_to have_css(
      'link[href*="/application"]:not([href*="nds_"])',
      visible: :all,
    )
  end

  it 'renders the signed-in header with the email menu and mobile menu' do
    render

    expect(rendered).to have_css('.official-banner')
    expect(rendered).to have_css(
      'header.account-header .account-header__menu-email',
      text: 'shell@example.com',
    )
    expect(rendered).to have_css('header.account-header details.account-mobile-menu')
  end

  it 'renders the side navigation next to the page content in main' do
    render

    expect(rendered).to have_css('.auth-page .account-shell .account-shell__nav nav.account-nav')
    expect(rendered).to have_css(
      '.account-shell main.account-shell__main#main-content h1',
      text: 'Page body',
    )
    expect(rendered).to have_css('main', count: 1)
    expect(rendered).to have_css('a.skip-link[href="#main-content"]')
  end

  it 'renders the NDS footer' do
    render

    expect(rendered).to have_css('.auth-page__footer-wrapper footer.page-footer')
  end

  it 'does not render the legacy account navigation' do
    render

    expect(rendered).not_to have_css('.sidenav')
    expect(rendered).not_to have_css('.usa-header')
    expect(rendered).not_to have_content(t('account.welcome'))
  end

  it 'marks no navigation item as current without a hint' do
    render

    expect(rendered).not_to have_css('.account-nav__link--current')
  end

  context 'when the page names the current navigation item' do
    before { view.content_for(:nds_account_nav_current, 'history') }

    it 'marks it in the side navigation and the mobile menu' do
      render

      expect(rendered).to have_css(
        '.account-shell__nav .account-nav__link--current',
        text: t('account.navigation.history'),
      )
      expect(rendered).to have_css(
        '.account-mobile-menu .account-nav__link--current',
        text: t('account.navigation.history'),
        visible: :all,
      )
    end
  end

  context 'with a flash message' do
    before { flash.now[:success] = 'Saved your changes.' }

    it 'renders it above the page content' do
      render

      expect(rendered).to have_css(
        'main .account-shell__flash .usa-alert',
        text: 'Saved your changes.',
      )
      expect(rendered.index('account-shell__flash')).to be < rendered.index('Page body')
    end
  end

  context 'without a flash message' do
    it 'renders no flash wrapper' do
      render

      expect(rendered).not_to have_css('.account-shell__flash')
    end
  end

  context 'when the page skips the layout flash' do
    before do
      flash.now[:success] = 'Saved your changes.'
      view.content_for(:skip_layout_flash, 'true')
    end

    it 'does not render the flash' do
      render

      expect(rendered).not_to have_content('Saved your changes.')
    end
  end

  context 'with pre-flash content' do
    before { view.content_for(:pre_flash_content, '<p>Before the flash</p>'.html_safe) }

    it 'renders it at the top of main' do
      render

      expect(rendered).to have_css('main.account-shell__main p', text: 'Before the flash')
    end
  end
end
