require 'rails_helper'

feature 'doc auth success step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    enable_doc_auth
    complete_doc_auth_steps_before_doc_success_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_success_step)
    expect(page).to have_content(t('doc_auth.forms.doc_success'))
  end

  it 'proceeds to the next page with valid info' do
    click_idv_continue

    expect(page).to have_current_path(idv_phone_path)
  end
end
