require 'rails_helper'

feature 'doc auth self image step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    enable_doc_auth
    complete_doc_auth_steps_before_self_image_step
    mock_assure_id_ok
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_self_image_step)
    expect(page).to have_content(t('doc_auth.headings.selfie'))
  end

  it 'proceeds to the next page with valid info' do
    first('input#_doc_auth_image', visible: false).set('data:image/png;base64,abc')
    click_idv_continue

    expect(page).to have_current_path(idv_review_url)
  end

  it 'does not proceed to the next page with invalid info' do
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:face_image).and_return([false, ''])

    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_self_image_step)
  end

  it 'creates a doc auth record' do
    first('input#_doc_auth_image', visible: false).set('data:image/png;base64,abc')
    click_idv_continue

    expect(DocAuth.count).to eq(1)
    expect(DocAuth.all[0].license_confirmed_at).to be_present
  end
end
