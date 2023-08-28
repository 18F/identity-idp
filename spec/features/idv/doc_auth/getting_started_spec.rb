require 'rails_helper'

RSpec.feature 'getting started step' do
  include IdvHelper
  include DocAuthHelper

  let(:fake_analytics) { FakeAnalytics.new }
  let(:sp_name) { 'Test SP' }

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSessionDecorator).to receive(:sp_name).and_return(sp_name)
    stub_const('AbTests::IDV_GETTING_STARTED', FakeAbTestBucket.new)
    AbTests::IDV_GETTING_STARTED.assign_all(:getting_started)

    visit_idp_from_sp_with_ial2(:oidc)
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_welcome_step
  end

  it 'displays expected content with javascript enabled', :js do
    expect(page).to have_current_path(idv_getting_started_path)

    # Try to continue with unchecked checkbox
    click_continue
    expect(page).to have_current_path(idv_getting_started_path)
    expect(page).to have_content(t('forms.validation.required_checkbox'))

    complete_getting_started_step
    expect(page).to have_current_path(idv_hybrid_handoff_path)
  end

  it 'logs "intro_paragraph" learn more link click' do
    click_on t('doc_auth.info.getting_started_learn_more')

    expect(fake_analytics).to have_logged_event(
      'External Redirect',
      step: 'getting_started',
      location: 'intro_paragraph',
      flow: 'idv',
      redirect_url: MarketingSite.help_center_article_url(
        category: 'verify-your-identity',
        article: 'how-to-verify-your-identity',
      ),
    )
  end

  context 'skipping hybrid_handoff step', :js, driver: :headless_chrome_mobile do
    before do
      complete_getting_started_step
    end

    it 'progresses to document capture' do
      expect(page).to have_current_path(idv_document_capture_url)
    end
  end

  def complete_getting_started_step
    complete_agreement_step # it does the right thing
  end
end
