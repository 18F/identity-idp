require 'rails_helper'

feature 'capture complete step' do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  before do
    complete_doc_capture_steps_before_capture_complete_step
    allow_any_instance_of(Browser).to receive(:mobile?).and_return(true)
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_capture_doc_capture_complete_step)
    expect(page).to have_content(t('doc_auth.headings.capture_complete'))
  end

  it 'shows the step indicator' do
    expect(page).to have_css(
      '.step-indicator__step--current',
      text: t('step_indicator.flows.idv.verify_id'),
    )
  end
end
