require 'rails_helper'

feature 'capture complete step' do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  before do
    complete_doc_capture_steps_before_capture_complete_step
    allow_any_instance_of(DeviceDetector).to receive(:device_type).and_return('mobile')
  end

  context 'document capture step enabled' do
    before do
      allow(FeatureManagement).to receive(:document_capture_step_enabled?).and_return(true)
    end

    it 'is on the correct page' do
      expect(page).to have_current_path(idv_capture_doc_capture_complete_step)
      expect(page).to have_content(t('doc_auth.headings.capture_complete'))
    end
  end

  context 'document capture step disabled' do
    before do
      allow(FeatureManagement).to receive(:document_capture_step_enabled?).and_return(false)
    end

    it 'is on the correct page' do
      expect(page).to have_current_path(idv_capture_doc_capture_complete_step)
      expect(page).to have_content(t('doc_auth.headings.capture_complete'))
    end
  end
end
