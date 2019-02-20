require 'rails_helper'

feature 'doc auth verify step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    enable_doc_auth
    complete_doc_auth_steps_before_address_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_address_path)
    expect(page).to have_content(t('doc_auth.headings.address'))
  end

  it 'allows the user to enter in a new address' do
    fill_out_address_form_ok

    click_idv_continue
    expect(page).to have_current_path(idv_doc_auth_verify_step)
  end

  it 'does not allows the user to enter bad address info' do
    fill_out_address_form_fail

    click_idv_continue
    expect(page).to have_current_path(idv_address_path)
  end
end
