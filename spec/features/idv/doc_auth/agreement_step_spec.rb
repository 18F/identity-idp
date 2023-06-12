require 'rails_helper'

RSpec.feature 'doc auth agreement step' do
  include DocAuthHelper

  def expect_doc_auth_first_step
    expect(page).to have_current_path(idv_doc_auth_agreement_step)
  end

  context 'when JS is enabled', :js do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_agreement_step
    end

    it 'shows an inline error if the user clicks continue without giving consent' do
      click_continue

      expect_doc_auth_first_step
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

      expect_doc_auth_first_step
      expect(page).to have_content(t('errors.doc_auth.consent_form'))
    end

    it 'allows the user to continue after checking the checkbox' do
      check t('doc_auth.instructions.consent', app_name: APP_NAME)
      click_continue

      expect(page).to have_current_path(idv_hybrid_handoff_path)
    end
  end

  context 'skipping upload step', :js, driver: :headless_chrome_mobile do
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

  context 'during the acuant maintenance window' do
    let(:start) { Time.zone.parse('2020-01-01T00:00:00Z') }
    let(:now) { Time.zone.parse('2020-01-01T12:00:00Z') }
    let(:finish) { Time.zone.parse('2020-01-01T23:59:59Z') }

    before do
      allow(IdentityConfig.store).to receive(:acuant_maintenance_window_start).and_return(start)
      allow(IdentityConfig.store).to receive(:acuant_maintenance_window_finish).and_return(finish)

      sign_in_and_2fa_user
      complete_doc_auth_steps_before_welcome_step
    end

    around do |ex|
      travel_to(now) { ex.run }
    end

    it 'renders the warning banner but no other content' do
      expect(page).to have_content('We are currently under maintenance')
      expect(page).to_not have_content(t('doc_auth.headings.welcome'))
    end
  end
end
