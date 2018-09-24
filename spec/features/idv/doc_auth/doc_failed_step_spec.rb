require 'rails_helper'

feature 'doc auth fail step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    enable_doc_auth
    complete_doc_auth_steps_before_doc_failed_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_doc_failed_step)
    expect(page).to have_content(t('doc_auth.errors.state_id_fail'))
  end
end
