require 'rails_helper'

RSpec.describe NDS::AccountNavigationComponent, type: :component do
  let(:options) { {} }
  let(:routes) { Rails.application.routes.url_helpers }

  subject(:rendered) { render_inline(described_class.new(**options)) }

  it 'renders the Home, Account, Security and History items in order' do
    expect(rendered).to have_css('nav.account-nav:not(.account-nav--mobile)')
    expect(rendered).to have_css(
      "nav.account-nav[aria-label='#{t('account.navigation.landmark_label')}']",
    )
    links = rendered.css('.account-nav__list .account-nav__item a.account-nav__link')
    expect(links.map { |link| link.text.squish }).to eq(
      [
        t('nds.account_nav.home'),
        t('nds.account_nav.account'),
        t('nds.account_nav.security'),
        t('account.navigation.history'),
      ],
    )
    expect(links.map { |link| link[:href] }).to eq(
      [
        routes.account_connected_services_path,
        routes.account_path,
        routes.account_two_factor_authentication_path,
        routes.account_history_path,
      ],
    )
  end

  it 'renders an icon in every item' do
    expect(rendered).to have_css('.account-nav__link svg.usa-icon[aria-hidden="true"]', count: 4)
  end

  it 'marks no item as current outside the account dashboard' do
    expect(rendered).not_to have_css('.account-nav__link--current')
    expect(rendered).not_to have_css('[aria-current]')
  end

  context 'with a current item' do
    let(:options) { { current: 'history' } }

    it 'marks only that item as the current page' do
      expect(rendered).to have_css('.account-nav__link--current', count: 1)
      expect(rendered).to have_css(
        '.account-nav__link--current[aria-current="page"]',
        text: t('account.navigation.history'),
      )
      expect(rendered).to have_css('[aria-current]', count: 1)
    end

    it 'swaps in the filled icon for the current item only' do
      icons = rendered.css('.account-nav__link svg').map(&:inner_html)

      expect(icons).to eq(
        %w[house profile_circle lock clock_filled].map do |icon|
          Nokogiri::HTML.fragment(
            NDS::IconComponent.markup_for("nds/icons/#{icon}/20.svg"),
          ).to_html
        end,
      )
    end
  end

  context 'with an unknown current item' do
    let(:options) { { current: 'settings' } }

    it 'raises a validation error' do
      expect { rendered }.to raise_error(ActiveModel::ValidationError)
    end
  end

  context 'when rendered by an account dashboard controller' do
    {
      Accounts::ConnectedServicesController => 'nds.account_nav.home',
      Users::ServiceProviderRevokeController => 'nds.account_nav.home',
      AccountsController => 'nds.account_nav.account',
      Users::EditPhoneController => 'nds.account_nav.account',
      Accounts::TwoFactorAuthenticationController => 'nds.account_nav.security',
      Users::WebauthnController => 'nds.account_nav.security',
      Accounts::HistoryController => 'account.navigation.history',
      EventsController => 'account.navigation.history',
    }.each do |controller_class, label_key|
      it "marks the #{label_key} item as current for #{controller_class}" do
        with_controller_class(controller_class) do
          expect(rendered).to have_css('.account-nav__link--current', text: t(label_key), count: 1)
        end
      end
    end

    it 'prefers an explicit current item' do
      with_controller_class(AccountsController) do
        rendered = render_inline(described_class.new(current: :security))

        expect(rendered).to have_css(
          '.account-nav__link--current',
          text: t('nds.account_nav.security'),
          count: 1,
        )
      end
    end
  end

  context 'in the mobile menu' do
    let(:options) { { mobile: true } }

    it 'adds the mobile modifier' do
      expect(rendered).to have_css('nav.account-nav.account-nav--mobile')
    end
  end
end
