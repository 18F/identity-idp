require 'rails_helper'

feature 'doc auth back image step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    enable_doc_auth
    complete_doc_auth_steps_before_back_image_step
    mock_assure_id_ok
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_back_image_step)
    expect(page).to have_content(t('doc_auth.headings.upload_back'))
  end

  it 'proceeds to the next page with valid info' do
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_doc_success_step)
  end

  it 'does not proceed to the next page if resolution fails' do
    allow_any_instance_of(Idv::Agent).to receive(:proof).
      and_return(success: false, errors: {})
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_back_image_step)
    expect(page).to have_content I18n.t('idv.failure.sessions.heading')
  end

  it 'does not proceed to the next page with invalid info' do
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_back_image).
      and_return([false, ''])
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_back_image_step)
  end

  it 'does not proceed to the next page with result=2' do
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:results).
      and_return([true, assure_id_results_with_result_2])
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_back_image_step)
  end
end
