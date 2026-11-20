require 'rails_helper'

RSpec.describe 'layouts/nds/application.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user, :fully_registered, email: 'form-page@example.com') }

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
    allow(view.request).to receive(:original_fullpath).and_return('/add/email')
    view.title = 'Add email'
    view.view_flow.set(:layout, '<h1>Page body</h1>'.html_safe)
  end

  it 'renders the default NDS chrome without the signed-in header' do
    render

    expect(rendered).to have_css('header.auth-page__top-chrome .auth-page__logo-banner')
    expect(rendered).not_to have_css('header.account-header')
    expect(rendered).to have_css('main.auth-page__main h1', text: 'Page body')
  end

  context 'when the page asks for the signed-in account header' do
    before { view.content_for(:nds_account_header, 'true') }

    it 'renders the account header in place of the default chrome' do
      render

      expect(rendered).to have_css('.official-banner', count: 1)
      expect(rendered).to have_css(
        'header.account-header .account-header__menu-email',
        text: 'form-page@example.com',
      )
      expect(rendered).to have_css('header.account-header details.account-mobile-menu')
      expect(rendered).not_to have_css('header.auth-page__top-chrome')
    end

    it 'keeps the page in the centered NDS main column, without the side navigation' do
      render

      expect(rendered).to have_css('main.auth-page__main#main-content h1', text: 'Page body')
      expect(rendered).not_to have_css('.account-shell')
    end

    it 'marks the navigation item the page names as current in the mobile menu' do
      view.content_for(:nds_account_nav_current, 'account')

      render

      expect(rendered).to have_css(
        '.account-mobile-menu .account-nav__link--current',
        text: t('nds.account_nav.account'),
        visible: :all,
      )
    end
  end
end
