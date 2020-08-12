require 'rails_helper'

feature 'doc auth self image step' do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  before do
    allow_any_instance_of(DeviceDetector).to receive(:device_type).and_return('mobile')
    allow(Figaro.env).to receive(:liveness_checking_enabled).and_return('true')
    complete_doc_capture_steps_before_capture_complete_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_capture_doc_capture_selfie_step)
  end

  it 'proceeds to the next page with valid info and acuant token gets updated after selfie' do
    expect(DocCapture.count).to eq(1)
    expect(DocCapture.first.acuant_token).to_not be_present

    attach_image
    click_idv_continue

    expect(DocCapture.first.acuant_token).to be_present
    expect(page).to have_current_path(idv_capture_doc_capture_complete_step)
  end

  it 'restarts doc auth if the document cannot be authenticated' do
    mock_general_doc_auth_client_error(:get_results)

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_capture_doc_mobile_front_image_step(nil))
    expect(page).to have_content(I18n.t('errors.doc_auth.general_error'))
  end

  it 'restarts doc auth if the selfie cannot be matched' do
    DocAuthMock::DocAuthMockClient.mock_response!(
      method: :post_selfie,
      response: DocAuthClient::Response.new(
        success: false,
        errors: [I18n.t('errors.doc_auth.selfie')],
      ),
    )

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_capture_doc_mobile_front_image_step(nil))
    expect(page).to have_content(t('errors.doc_auth.selfie'))
  end
end
