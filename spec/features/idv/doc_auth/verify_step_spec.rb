require 'rails_helper'

feature 'doc auth verify step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    enable_doc_auth
    complete_doc_auth_steps_before_verify_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_verify_step)
    expect(page).to have_content(t('doc_auth.headings.verify'))
  end

  it 'proceeds to the next page upon confirmation' do
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_success_step)
  end

  it 'proceeds to the address page if the user clicks change address' do
    click_link t('doc_auth.buttons.change_address')

    expect(page).to have_current_path(idv_address_path)
  end

  it 'proceeds to the ssn page if the user clicks change ssn' do
    click_button t('doc_auth.buttons.change_ssn')

    expect(page).to have_current_path(idv_doc_auth_ssn_step)
  end

  it 'does not proceed to the next page if resolution fails' do
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_known_bad_ssn
    click_idv_continue
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_doc_failed_step)
  end

  it 'does not proceed to the next page if ssn is a duplicate' do
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_duplicate_ssn
    click_idv_continue
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_doc_failed_step)
  end
end
