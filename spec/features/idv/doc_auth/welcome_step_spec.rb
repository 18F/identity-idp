require 'rails_helper'

feature 'doc auth welcome step' do
  include IdvHelper
  include DocAuthHelper

  def expect_doc_auth_upload_step
    expect(page).to have_current_path(idv_doc_auth_upload_step)
  end

  let(:fake_analytics) { FakeAnalytics.new }
  let(:maintenance_window) { [] }
  let(:sp_name) { 'Test SP' }

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSessionDecorator).to receive(:sp_name).and_return(sp_name)
    start, finish = maintenance_window
    allow(IdentityConfig.store).to receive(:acuant_maintenance_window_start).and_return(start)
    allow(IdentityConfig.store).to receive(:acuant_maintenance_window_finish).and_return(finish)

    visit_idp_from_sp_with_ial2(:oidc)
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_welcome_step
  end

  it 'logs return to sp link click' do
    click_on t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name)

    expect(fake_analytics).to have_logged_event(
      'Return to SP: Failed to proof',
      step: 'welcome',
      location: 'missing_items',
    )
  end

  it 'logs supported documents troubleshooting link click' do
    click_on t('idv.troubleshooting.options.supported_documents')

    expect(fake_analytics).to have_logged_event(
      'External Redirect',
      step: 'welcome',
      location: 'missing_items',
      flow: 'idv',
      redirect_url: MarketingSite.help_center_article_url(
        category: 'verify-your-identity',
        article: 'accepted-state-issued-identification',
      ),
    )
  end

  it 'logs missing items troubleshooting link click' do
    click_on t('idv.troubleshooting.options.learn_more_address_verification_options')

    expect(fake_analytics).to have_logged_event(
      'External Redirect',
      step: 'welcome',
      location: 'missing_items',
      flow: 'idv',
      redirect_url: MarketingSite.help_center_article_url(
        category: 'verify-your-identity',
        article: 'phone-number-and-phone-plan-in-your-name',
      ),
    )
  end

  context 'skipping upload step', :js, driver: :headless_chrome_mobile do
    it 'progresses to the agreement screen' do
      click_continue
      expect(page).to have_current_path(idv_doc_auth_agreement_step)
    end
  end

  context 'cancelling' do
    let(:sp_name) { 'Test SP' }
    before do
      sp = build_stubbed(:service_provider, friendly_name: sp_name)
      allow_any_instance_of(ApplicationController).to receive(:current_sp).and_return(sp)
    end

    it 'logs events when returning to sp' do
      click_on t('links.cancel')
      expect(fake_analytics).to have_logged_event(Analytics::IDV_CANCELLATION, step: 'welcome')

      click_on t('forms.buttons.cancel')
      expect(fake_analytics).to have_logged_event(
        Analytics::IDV_CANCELLATION_CONFIRMED,
        step: 'welcome',
      )

      click_on "‹ #{t('links.back_to_sp', sp: sp_name)}"
      expect(fake_analytics).to have_logged_event(
        'Return to SP: Failed to proof',
        step: 'welcome',
        location: 'cancel',
      )
    end
  end

  context 'during the acuant maintenance window' do
    context 'during the acuant maintenance window' do
      let(:maintenance_window) do
        [Time.zone.parse('2020-01-01T00:00:00Z'), Time.zone.parse('2020-01-01T23:59:59Z')]
      end
      let(:now) { Time.zone.parse('2020-01-01T12:00:00Z') }

      around do |ex|
        travel_to(now) { ex.run }
      end

      it 'renders the warning banner but no other content' do
        expect(page).to have_content('We are currently under maintenance')
        expect(page).to_not have_content(t('doc_auth.headings.welcome'))
      end
    end
  end
end
