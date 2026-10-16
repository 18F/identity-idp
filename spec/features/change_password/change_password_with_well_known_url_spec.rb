require 'rails_helper'

RSpec.feature 'Changing password via the well-known change-password URL' do
  let(:well_known_change_password_path) { '/.well-known/change-password' }

  scenario 'a signed-in user is redirected to the manage password page' do
    sign_in_and_2fa_user

    visit well_known_change_password_path

    expect(page).to have_current_path(manage_password_path)
  end

  scenario 'a signed-out user is redirected to the sign-in page' do
    visit well_known_change_password_path

    expect(page).to have_current_path(new_user_session_path)
  end
end
