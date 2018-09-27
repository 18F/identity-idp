require 'rails_helper'

feature 'doc auth front image step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    enable_doc_auth
    complete_doc_auth_steps_before_front_image_step
    mock_assure_id_ok
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_front_image_step)
    expect(page).to have_content(t('doc_auth.headings.upload_front'))
  end

  it 'proceeds to the next page with valid info' do
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_back_image_step)
  end

  it 'does not proceed to the next page with invalid info' do
    mock_assure_id_fail
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_front_image_step)
  end
end
