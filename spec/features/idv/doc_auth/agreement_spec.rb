require 'rails_helper'

RSpec.feature 'doc auth agreement step' do
  include DocAuthHelper

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_agreement_controller_enabled).
      and_return(true)
  end

  context 'when JS is enabled', :js do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_agreement_step
    end

    it 'shows an inline error if the user clicks continue without giving consent' do
      expect(page).to have_content(t('step_indicator.flows.idv.getting_started'))
      click_continue

      expect(page).to have_current_path(idv_agreement_url)
      expect(page).to have_content(t('forms.validation.required_checkbox'))
    end

    it 'allows the user to continue after checking the checkbox' do
      check t('doc_auth.instructions.consent', app_name: APP_NAME)
      click_continue

      expect(page).to have_current_path(idv_hybrid_handoff_path)
    end
  end

  context 'when JS is disabled' do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_agreement_step
    end

    it 'shows the notice if the user clicks continue without giving consent' do
      click_continue

      expect(page).to have_current_path(idv_agreement_url)
      expect(page).to have_content(t('errors.doc_auth.consent_form'))
    end

    it 'allows the user to continue after checking the checkbox' do
      check t('doc_auth.instructions.consent', app_name: APP_NAME)
      click_continue

      expect(page).to have_current_path(idv_hybrid_handoff_path)
    end
  end

  context 'skipping hybrid_handoff step', :js, driver: :headless_chrome_mobile do
    let(:fake_analytics) { FakeAnalytics.new }

    before do
      allow_any_instance_of(ApplicationController).
        to receive(:analytics).and_return(fake_analytics)

      sign_in_and_2fa_user
      complete_doc_auth_steps_before_agreement_step
      complete_agreement_step
    end

    it 'progresses to document capture' do
      expect(page).to have_current_path(idv_document_capture_url)
    end
  end
end
