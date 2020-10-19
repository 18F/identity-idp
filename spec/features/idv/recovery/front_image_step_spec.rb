require 'rails_helper'

feature 'recovery front image step' do
  include IdvStepHelper
  include DocAuthHelper
  include RecoveryHelper

  let(:user) { create(:user) }
  let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: '1234' }) }

  before do
    allow(FeatureManagement).to receive(:document_capture_step_enabled?).and_return(false)

    sign_in_before_2fa(user)
    complete_recovery_steps_before_front_image_step(user)
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_recovery_front_image_step)
    expect(page).to have_content(t('doc_auth.headings.upload_front'))
  end

  it 'proceeds to the next page with valid info' do
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_recovery_back_image_step)
  end

  it 'allows the use of a base64 encoded data url representation of the image' do
    attach_image_data_url
    click_idv_continue

    expect(page).to have_current_path(idv_recovery_back_image_step)
    expect(DocAuth::Mock::DocAuthMockClient.last_uploaded_front_image).to eq(
      doc_auth_image_data_url_data,
    )
  end

  it 'does not proceed to the next page with invalid info' do
    mock_general_doc_auth_client_error(:create_document)
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_recovery_front_image_step)
  end
end
