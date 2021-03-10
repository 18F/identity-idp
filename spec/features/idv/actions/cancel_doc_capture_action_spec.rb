require 'rails_helper'

feature 'doc auth cancel doc capture action' do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  before do
    complete_doc_capture_steps_before_document_capture_step
  end

  it 'returns to the sign in screen after clicking cancel' do
    expect(page).to have_current_path(idv_capture_doc_document_capture_step)

    click_on t('links.cancel')

    expect(page).to have_current_path(root_path)
  end

  it 'allows the user to restart the hybrid session and cancel again' do
    expect(page).to have_current_path(idv_capture_doc_document_capture_step)

    click_on t('links.cancel')

    expect(page).to have_current_path(root_path)

    visit idv_capture_doc_document_capture_step
    expect(page).to have_current_path(idv_capture_doc_document_capture_step)

    click_on t('links.cancel')

    expect(page).to have_current_path(root_path)
  end
end
