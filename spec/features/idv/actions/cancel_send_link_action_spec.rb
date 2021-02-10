require 'rails_helper'

feature 'doc auth cancel send link action' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_send_link_step
  end

  it 'returns to upload step from send link' do
    click_doc_auth_back_link

    expect(page).to have_current_path(idv_doc_auth_upload_step)
  end

  it 'returns to upload step from link sent' do
    fill_out_doc_auth_phone_form_ok
    click_idv_continue

    click_doc_auth_back_link

    expect(page).to have_current_path(idv_doc_auth_upload_step)
  end
end
