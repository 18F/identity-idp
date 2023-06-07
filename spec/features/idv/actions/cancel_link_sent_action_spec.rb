require 'rails_helper'

feature 'doc auth cancel link sent action' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_link_sent_step
  end

  it 'returns to link sent step' do
    click_doc_auth_back_link

    expect(page).to have_current_path(idv_hybrid_handoff_path)
  end
end
