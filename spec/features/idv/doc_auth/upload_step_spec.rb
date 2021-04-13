require 'rails_helper'

feature 'doc auth upload step' do
  include IdvStepHelper
  include DocAuthHelper

  let(:ial2_step_indicator_enabled) { true }

  before do
    allow(IdentityConfig.store).to receive(:ial2_step_indicator_enabled).
      and_return(ial2_step_indicator_enabled)
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_upload_step
  end

  context 'on a mobile device' do
    before do
      allow_any_instance_of(DeviceDetector).to receive(:device_type).and_return('mobile')
    end

    it 'is on the correct page' do
      expect(page).to have_current_path(idv_doc_auth_upload_step)
    end

    it 'proceeds to send link via email page when user chooses to upload from computer' do
      click_on t('doc_auth.info.upload_computer_link')
      expect(page).to have_current_path(idv_doc_auth_email_sent_step)
    end

    it 'proceeds to document capture when user chooses to use phone' do
      click_on t('doc_auth.buttons.use_phone')
      expect(page).to have_current_path(idv_doc_auth_document_capture_step)
    end
  end

  context 'on a desktop device' do
    before do
      allow_any_instance_of(DeviceDetector).to receive(:device_type).and_return('desktop')
    end

    it 'is on the correct page' do
      expect(page).to have_current_path(idv_doc_auth_upload_step)
    end

    it 'proceeds to document capture when user chooses to upload from computer' do
      click_on t('doc_auth.info.upload_computer_link')
      expect(page).to have_current_path(idv_doc_auth_document_capture_step)
    end

    it 'proceeds to send link to phone page when user chooses to use phone' do
      click_on t('doc_auth.buttons.use_phone')
      expect(page).to have_current_path(idv_doc_auth_send_link_step)
    end
  end

  context 'ial2 step indicator enabled' do
    it 'shows the step indicator' do
      expect(page).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.verify_id'),
      )
    end
  end

  context 'ial2 step indicator disabled' do
    let(:ial2_step_indicator_enabled) { false }

    it 'does not show the step indicator' do
      expect(page).not_to have_css('.step-indicator')
    end
  end
end
