require 'rails_helper'

RSpec.feature 'welcome step' do
  include IdvHelper
  include DocAuthHelper

  let(:fake_analytics) { FakeAnalytics.new }
  let(:sp_name) { 'Test SP' }

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return(sp_name)

    visit_idp_from_sp_with_ial2(:oidc)
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_welcome_step
  end

  it 'logs return to sp link click' do
    click_on t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name)

    expect(fake_analytics).to have_logged_event(
      'Return to SP: Failed to proof',
      flow: nil,
      location: 'missing_items',
      redirect_url: instance_of(String),
      step: 'welcome',
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
    within '.troubleshooting-options' do
      click_on t('idv.troubleshooting.options.learn_more_address_verification_options')
    end

    expect(fake_analytics).to have_logged_event(
      'External Redirect',
      step: 'welcome',
      location: 'missing_items',
      flow: 'idv',
      redirect_url: MarketingSite.help_center_article_url(
        category: 'verify-your-identity',
        article: 'phone-number',
      ),
    )
  end

  it 'logs "you will need" learn more link click' do
    within '.usa-process-list' do
      click_on t('idv.troubleshooting.options.learn_more_address_verification_options')
    end

    expect(fake_analytics).to have_logged_event(
      'External Redirect',
      step: 'welcome',
      location: 'you_will_need',
      flow: 'idv',
      redirect_url: MarketingSite.help_center_article_url(
        category: 'verify-your-identity',
        article: 'phone-number',
      ),
    )
  end
end
