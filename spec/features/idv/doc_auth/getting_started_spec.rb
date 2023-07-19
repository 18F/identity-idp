require 'rails_helper'

RSpec.feature 'getting started step' do
  include IdvHelper
  include DocAuthHelper

  let(:fake_analytics) { FakeAnalytics.new }
  let(:maintenance_window) { [] }
  let(:sp_name) { 'Test SP' }

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSessionDecorator).to receive(:sp_name).and_return(sp_name)
    allow_any_instance_of(Idv::WelcomeController).to receive(:getting_started_a_b_test_bucket).
      and_return(:new)

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

  context 'when JS is disabled' do
    it 'shows the notice if the user clicks continue without giving consent' do
      click_continue

      expect(page).to have_current_path(idv_getting_started_url)
      expect(page).to have_content(t('errors.doc_auth.consent_form'))
    end

    it 'allows the user to continue after checking the checkbox' do
      check t('doc_auth.instructions.consent', app_name: APP_NAME)
      click_continue

      expect(page).to have_current_path(idv_hybrid_handoff_path)
    end
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
