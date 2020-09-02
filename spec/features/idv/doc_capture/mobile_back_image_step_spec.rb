require 'rails_helper'

feature 'doc capture mobile back image step' do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  before do
    allow(FeatureManagement).to receive(:document_capture_step_enabled?).and_return(false)
    complete_doc_capture_steps_before_mobile_back_image_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_capture_doc_capture_mobile_back_image_step)
    expect(page).to have_content(t('doc_auth.headings.take_pic_back'))
  end

  it 'proceeds to the next page with valid info and updates acuant token' do
    expect(DocCapture.count).to eq(1)
    expect(DocCapture.first.acuant_token).to_not be_present

    attach_image
    click_idv_continue

    expect(DocCapture.first.acuant_token).to be_present
    expect(page).to have_current_path(idv_capture_doc_capture_complete_step)
  end

  it 'allows the use of a base64 encoded data url representation of the image' do
    attach_image_data_url
    click_idv_continue

    expect(page).to have_current_path(idv_capture_doc_capture_complete_step)
    expect(DocAuth::Mock::DocAuthMockClient.last_uploaded_back_image).to eq(
      doc_auth_image_data_url_data,
    )
  end

  it 'does not proceed to the next page with invalid info' do
    mock_general_doc_auth_client_error(:post_back_image)

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_capture_doc_capture_mobile_back_image_step)
  end

  it 'does not attempt to verify the document if selfie checking is enabled' do
    allow(Figaro.env).to receive(:liveness_checking_enabled).and_return('true')

    mock_client = DocAuth::Mock::DocAuthMockClient.new
    allow(DocAuth::Mock::DocAuthMockClient).to receive(:new).and_return(mock_client)

    expect(mock_client).to_not receive(:get_results)

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_capture_doc_capture_selfie_step)
  end
end
