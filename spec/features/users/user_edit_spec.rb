require 'rails_helper'

# Feature: User edit
#   As a user
#   I want to edit my user profile
#   So I can change my email address
feature 'User edit' do
  scenario 'user sees error message if form is submitted without email', js: true do
    user = sign_in_and_2fa_user

    visit edit_user_registration_path
    fill_in 'Email', with: ''
    fill_in 'Current password', with: user.password
    click_button 'Update'

    expect(page).to have_content 'Please fill in all required fields'
  end

  scenario 'form submitted without current password and JS is on', js: true do
    sign_in_and_2fa_user

    visit edit_user_registration_path
    fill_in 'Mobile', with: ''
    click_button 'Update'

    expect(page).to have_content 'Please fill in all required fields'
  end

  scenario 'user can see and use password visibility toggle', js: true do
    sign_in_and_2fa_user

    visit edit_user_registration_path
    expect(page).to have_css('#pw-toggle')

    click_button 'Show'
    expect(page).to have_content 'Hide'
  end
end
