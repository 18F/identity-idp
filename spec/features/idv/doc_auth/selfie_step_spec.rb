require 'rails_helper'

feature 'doc auth self image step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    mock_acuant_selfie_ok
    allow(Figaro.env).to receive(:liveness_checking_enabled).and_return('true')
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_ssn_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_selfie_step)
  end

  it 'proceeds to the next page with valid info' do
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_ssn_step)
  end

  it 'restarts doc auth upon failure' do
    allow_any_instance_of(Acuant::Liveness).to receive(:call).and_return(nil)
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_front_image_step)
    expect(page).to have_content(t('errors.doc_auth.selfie'))
  end
end
