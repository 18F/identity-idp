require 'rails_helper'

feature 'cac proofing welcome step' do
  include CacProofingHelper

  before do
    enable_cac_proofing
    sign_in_and_2fa_user
    complete_cac_proofing_steps_before_welcome_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_cac_proofing_welcome_step)
  end
end
