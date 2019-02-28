require 'rails_helper'

feature 'capture complete step' do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  before do
    enable_doc_auth
    complete_doc_capture_steps_before_capture_complete_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_capture_doc_capture_complete_step)
    expect(page).to have_content(t('doc_auth.headings.capture_complete'))
  end
end
