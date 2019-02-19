require 'rails_helper'

feature 'doc auth ssn step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    enable_doc_auth
    complete_doc_auth_steps_before_ssn_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_ssn_step)
    expect(page).to have_content(t('doc_auth.headings.ssn'))
  end

  it 'proceeds to the next page with valid info' do
    fill_out_ssn_form_ok
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_verify_step)
  end

  it 'does not proceed to the next page with invalid info' do
    fill_out_ssn_form_fail
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_ssn_step)
  end
end
