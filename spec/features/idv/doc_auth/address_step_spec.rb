require 'rails_helper'

feature 'doc auth verify step', :js do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_address_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_address_path)
    expect(page).to have_content(t('doc_auth.headings.address'))
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
  end

  it 'allows the user to enter in a new address' do
    fill_out_address_form_ok

    click_button t('forms.buttons.submit.update')
    expect(page).to have_current_path(idv_doc_auth_verify_step)
  end

  it 'does not allows the user to enter bad address info' do
    fill_out_address_form_fail

    click_button t('forms.buttons.submit.update')
    expect(page).to have_current_path(idv_address_path)
  end

  it 'allows the user to click back to return to the verify step' do
    click_doc_auth_back_link

    expect(page).to have_current_path(idv_doc_auth_verify_step)
  end

  it 'sends the user to start doc auth if there is no pii from the document in session' do
    visit sign_out_url
    sign_in_and_2fa_user
    visit idv_address_path

    expect(page).to have_current_path(idv_doc_auth_welcome_step)
  end
end
