require 'rails_helper'

feature 'in person find usps step' do
  include InPersonHelper

  before do
    enable_in_person_proofing
    sign_in_and_2fa_user
    complete_in_person_steps_before_find_usps_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_in_person_find_usps_step)
  end

  it 'proceeds to next page with a zip code' do
    fill_in :in_person_zip_code, with: Faker::Address.zip_code
    click_continue

    expect(page).to have_current_path(idv_in_person_usps_list_step)
  end
end
