require 'rails_helper'

feature 'in person welcome step' do
  include InPersonHelper

  before do
    enable_in_person_proofing
    sign_in_and_2fa_user
    complete_in_person_steps_before_welcome_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_in_person_welcome_step)
  end
end
