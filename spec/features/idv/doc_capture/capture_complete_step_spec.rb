require 'rails_helper'

feature 'capture complete step' do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  let(:ial2_step_indicator_enabled) { true }

  before do
    allow(IdentityConfig.store).to receive(:ial2_step_indicator_enabled).
      and_return(ial2_step_indicator_enabled)
    complete_doc_capture_steps_before_capture_complete_step
    allow_any_instance_of(DeviceDetector).to receive(:device_type).and_return('mobile')
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_capture_doc_capture_complete_step)
    expect(page).to have_content(t('doc_auth.headings.capture_complete'))
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
