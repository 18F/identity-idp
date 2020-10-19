require 'rails_helper'

feature 'doc auth mobile front image step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_mobile_front_image_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_mobile_front_image_step)
    expect(page).to have_content(t('doc_auth.headings.take_pic_front'))
  end

  it 'proceeds to the next page with valid info' do
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_mobile_back_image_step)
  end

  it 'allows the use of a base64 encoded data url representation of the image' do
    attach_image_data_url
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_mobile_back_image_step)
    expect(IdentityDocAuth::Mock::DocAuthMockClient.last_uploaded_front_image).to eq(
      doc_auth_image_data_url_data,
    )
  end

  it 'does not proceed to the next page with invalid info' do
    mock_general_doc_auth_client_error(:create_document)
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_mobile_front_image_step)
  end
end
