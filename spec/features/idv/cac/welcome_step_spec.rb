require 'rails_helper'

feature 'cac proofing welcome step' do
  include CacProofingHelper
  include DocAuthHelper

  let(:user) { user_with_2fa }
  before do
    enable_doc_auth
    enable_cac_proofing
    sign_in_and_2fa_user(user)
    complete_cac_proofing_steps_before_welcome_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_cac_proofing_welcome_step)
  end
end
