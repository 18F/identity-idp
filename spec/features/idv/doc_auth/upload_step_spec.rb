require 'rails_helper'

feature 'doc auth upload step' do
  include IdvStepHelper
  include DocAuthHelper

  let(:fake_analytics) { FakeAnalytics.new }
  let(:fake_attempts_tracker) { IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new }

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_upload_step
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ApplicationController).to receive(:irs_attempts_api_tracker).
      and_return(fake_attempts_tracker)
  end

  context 'on a mobile device' do
    before do
      allow(BrowserCache).to receive(:parse).and_return(mobile_device)
    end

    it 'is on the correct page' do
      expect(page).to have_current_path(idv_doc_auth_upload_step)
      expect(page).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.verify_id'),
      )
    end

    it 'proceeds to send link via email page when user chooses to upload from computer' do
      expect(fake_attempts_tracker).to receive(
        :document_upload_method_selected,
      ).with({ upload_method: 'desktop' })

      click_on t('doc_auth.info.upload_computer_link')

      expect(page).to have_current_path(idv_doc_auth_email_sent_step)
      expect(fake_analytics).to have_logged_event(
        "IdV: #{Analytics::DOC_AUTH.downcase} upload submitted",
        hash_including(step: 'upload', destination: :email_sent),
      )
    end

    it 'proceeds to document capture when user chooses to use phone' do
      expect(fake_attempts_tracker).to receive(
        :document_upload_method_selected,
      ).with({ upload_method: 'mobile' })

      click_on t('doc_auth.buttons.use_phone')

      expect(page).to have_current_path(idv_doc_auth_document_capture_step)

      expect(fake_analytics).to have_logged_event(
        "IdV: #{Analytics::DOC_AUTH.downcase} upload submitted",
        hash_including(step: 'upload', destination: :document_capture),
      )
    end
  end

  context 'on a desktop device' do
    it 'is on the correct page' do
      expect(page).to have_current_path(idv_doc_auth_upload_step)
      expect(page).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.verify_id'),
      )
    end

    it 'proceeds to document capture when user chooses to upload from computer' do
      expect(fake_attempts_tracker).to receive(
        :document_upload_method_selected,
      ).with({ upload_method: 'desktop' })

      click_on t('doc_auth.info.upload_computer_link')

      expect(page).to have_current_path(idv_doc_auth_document_capture_step)
      expect(fake_analytics).to have_logged_event(
        "IdV: #{Analytics::DOC_AUTH.downcase} upload submitted",
        hash_including(step: 'upload', destination: :document_capture),
      )
    end

    it 'proceeds to send link to phone page when user chooses to use phone' do
      expect(fake_attempts_tracker).to receive(
        :document_upload_method_selected,
      ).with({ upload_method: 'mobile' })

      click_on t('doc_auth.buttons.use_phone')

      expect(page).to have_current_path(idv_doc_auth_send_link_step)
      expect(fake_analytics).to have_logged_event(
        "IdV: #{Analytics::DOC_AUTH.downcase} upload submitted",
        hash_including(step: 'upload', destination: :send_link),
      )
    end
  end
end
