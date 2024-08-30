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

  it 'logs "intro_paragraph" learn more link click' do
    click_on t('doc_auth.info.getting_started_learn_more')

    expect(fake_analytics).to have_logged_event(
      'External Redirect',
      step: 'welcome',
      location: 'intro_paragraph',
      flow: 'idv',
      redirect_url: MarketingSite.help_center_article_url(
        category: 'verify-your-identity',
        article: 'overview',
      ),
    )
  end
end
