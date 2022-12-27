require 'rails_helper'

feature 'doc auth welcome step' do
  include DocAuthHelper

  def expect_doc_auth_upload_step
    expect(page).to have_current_path(idv_doc_auth_upload_step)
  end

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

      expect_doc_auth_upload_step
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

      expect_doc_auth_upload_step
    end
  end

  context 'skipping upload step', :js, driver: :headless_chrome_mobile do
    let(:fake_analytics) { FakeAnalytics.new }

    before do
      allow_any_instance_of(ApplicationController).
        to receive(:analytics).and_return(fake_analytics)

      sign_in_and_2fa_user
      complete_doc_auth_steps_before_agreement_step
      check t('doc_auth.instructions.consent', app_name: APP_NAME)
      click_continue
    end

    it 'progresses to document capture' do
      expect(page).to have_current_path(idv_doc_auth_document_capture_step)
    end

    it 'logs analytics for upload step' do
      log = DocAuthLog.last
      expect(log.upload_view_count).to eq 1
      expect(log.upload_view_at).not_to be_nil

      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth upload visited',
        analytics_id: 'Doc Auth',
        flow_path: 'standard',
        step: 'upload', step_count: 1,
        irs_reproofing: false,
        acuant_sdk_upgrade_ab_test_bucket: :default
      )
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth upload submitted',
        hash_including(step: 'upload', step_count: 2, success: true),
      )
    end
  end

  context 'during the acuant maintenance window' do
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
end
