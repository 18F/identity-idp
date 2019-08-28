require 'rails_helper'

feature 'cac proofing enter info step' do
  include CacProofingHelper

  before do
    enable_cac_proofing
    sign_in_and_2fa_user
    complete_cac_proofing_steps_before_enter_info_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_cac_proofing_enter_info_step)
  end

  it 'proceeds to the next page' do
    fill_out_cac_proofing_form_ok
    click_continue

    expect(page).to have_current_path(idv_cac_proofing_verify_step)
  end
end
