require 'rails_helper'

feature 'in person usps list step' do
  include InPersonHelper

  before do
    enable_in_person_proofing
    sign_in_and_2fa_user
    complete_in_person_steps_before_usps_list_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_in_person_usps_list_step)
  end

  it 'proceeds to the next page' do
    click_continue
    expect(page).to have_current_path(idv_in_person_enter_info_step)
  end
end
