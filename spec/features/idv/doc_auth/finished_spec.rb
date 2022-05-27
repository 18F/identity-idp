require 'rails_helper'

feature 'doc auth success step', :js do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
    complete_all_doc_auth_steps
  end

  it 'is on the correct page after clicking continue on final step' do
    expect(page).to have_current_path(idv_phone_path)
  end

  it 'is on the correct page when using the back button after final step' do
    expect(page).to have_current_path(idv_phone_path)
    visit '/verify/doc_auth/verify'
    expect(page).to have_current_path(idv_phone_path)
  end
end
