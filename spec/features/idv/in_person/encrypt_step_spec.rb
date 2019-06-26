require 'rails_helper'

feature 'in person encrypt step' do
  include InPersonHelper

  before do
    enable_in_person_proofing
    sign_in_and_2fa_user
    complete_in_person_steps_before_encrypt_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_in_person_encrypt_step)
  end

  it 'proceeds to the next step' do
    click_continue

    expect(page).to have_current_path(idv_in_person_bar_code_step)
  end
end
