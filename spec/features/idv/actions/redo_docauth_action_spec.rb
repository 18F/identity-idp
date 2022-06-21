require 'rails_helper'

feature 'doc auth cancel link sent action' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_verify_step_with_barcode_warning
  end

  it 'returns to send link step' do
    click_upload_new_photos_link

    expect(page).to have_current_path(idv_doc_auth_document_capture_step)
  end
end
