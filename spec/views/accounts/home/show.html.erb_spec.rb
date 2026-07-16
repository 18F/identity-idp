# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'accounts/home/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_personal_key) }
  let(:now) { Time.zone.local(2026, 7, 10, 13, 0, 0) }
  let(:category) { nil }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(
      :presenter,
      AccountHomePresenter.new(user:, decrypted_pii: nil, now:, category:),
    )
  end

  context 'with no connected apps (empty state, node 11893-26303)' do
    it 'renders the greeting hero as the only h1' do
      render

      page = Capybara.string(rendered)
      expect(page).to have_css('h1.ads-dashboard-home__greeting', count: 1)
      expect(page.find('h1')).to have_text(t('account.dashboard.greeting.afternoon'))
    end

    it 'omits the connected services section entirely' do
      render

      expect(rendered).to_not have_content(t('headings.account.connected_services'))
    end

    it 'omits the filter chips' do
      render

      expect(rendered).to_not have_css('.ads-discovery__chip')
    end

    it 'renders the discovery section with the full catalog' do
      render

      page = Capybara.string(rendered)
      expect(page).to have_css('h2#discovery-heading', text: t('account.dashboard.discovery.title'))
      expect(page).to have_css('.ads-discovery__rows > li', count: FeaturedService.all.length)
    end

    it 'gives each discovery service an h3 name and an external Visit link' do
      render

      page = Capybara.string(rendered)
      expect(page).to have_css('h3.ads-discovery-service__title', text: 'Internal Revenue Service')
      visit_link = page.first('.ads-discovery-service__actions a')
      expect(visit_link[:target]).to eq('_blank')
      expect(visit_link[:rel]).to include('noopener')
      expect(visit_link[:'aria-label']).to include(t('links.new_tab'))
    end
  end

  context 'with connected apps (homepage, node 11876-24688)' do
    let!(:identity) do
      create(:service_provider_identity, :active, user:, verified_attributes: ['email'])
    end

    it 'renders the connected services section with an h2 header' do
      render

      page = Capybara.string(rendered)
      expect(page).to have_css(
        'h2#connected-services-heading',
        text: t('headings.account.connected_services'),
      )
      expect(page).to have_css('.ads-connected-services__rows > li')
    end

    it 'levels the connected service name as an h3 (below the section h2)' do
      render

      expect(rendered).to have_css('h3.ads-connected-service__title', text: identity.display_name)
    end

    it 'renders the filter chips with All services selected by default' do
      render

      page = Capybara.string(rendered)
      expect(page).to have_css('.ads-discovery__chip', minimum: 7)
      current = page.find('.ads-discovery__chip--current')
      expect(current).to have_text(t('account.dashboard.discovery.categories.all'))
      expect(current[:'aria-current']).to eq('true')
    end

    it 'maintains a valid h1 > h2 > h3 heading order' do
      render

      levels = Capybara.string(rendered).all('h1, h2, h3').map { |n| n.tag_name[1].to_i }
      expect(levels.first).to eq(1)
      levels.each_cons(2) { |a, b| expect(b - a).to be <= 1 }
    end
  end

  context 'post-signup welcome modal (node 11929-10827)' do
    it 'renders the welcome dialog closed on the page' do
      render

      page = Capybara.string(rendered)
      dialog = page.find('dialog#welcome-modal', visible: :all)
      expect(dialog[:class]).to include('ads-modal--wide')
      expect(dialog).to_not have_selector('[open]')
    end

    it 'titles the modal with an h2 and the welcome copy' do
      render

      page = Capybara.string(rendered)
      expect(page).to have_css(
        'dialog#welcome-modal h2.ads-modal__title',
        text: t('account.dashboard.welcome_modal.title'),
        visible: :all,
      )
      expect(page).to have_css(
        'dialog#welcome-modal .ads-modal__description',
        text: t('account.dashboard.welcome_modal.body'),
        visible: :all,
      )
      expect(page).to have_css(
        'dialog#welcome-modal .ads-modal__actions button',
        text: t('account.dashboard.welcome_modal.cta'),
        visible: :all,
      )
    end

    it 'renders the agency montage header as a decorative image' do
      render

      img = Capybara.string(rendered).find(
        'dialog#welcome-modal .ads-modal__media img',
        visible: :all,
      )
      expect(img[:alt]).to eq('')
      expect(img[:'aria-hidden']).to eq('true')
      expect(img[:src]).to include('welcome-modal-agencies')
    end

    it 'loads the welcome-modal javascript pack' do
      expect(view).to receive(:javascript_packs_tag_once).with('welcome-modal')

      render
    end
  end

  context 'when a filter matches no services' do
    let!(:identity) do
      create(:service_provider_identity, :active, user:, verified_attributes: ['email'])
    end
    let(:category) { 'veterans_and_military' }

    before do
      allow_any_instance_of(AccountHomePresenter)
        .to receive(:featured_services).and_return([])
    end

    it 'shows the empty filtered message' do
      render

      expect(rendered).to have_content(t('account.dashboard.discovery.empty'))
    end
  end
end
