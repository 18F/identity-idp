require 'rails_helper'

# Feature: User edit
#   As a user
#   I want to edit my user profile
#   So I can change my email address
feature 'User edit' do
  scenario 'user sees error message if form is submitted without email', js: true do
    sign_in_and_2fa_user

    visit edit_email_path
    fill_in 'Email', with: ''
    click_button 'Update'

    expect(page).to have_content 'Please fill in this field.'
  end

  scenario 'user sees error message if form is submitted without phone number', js: true do
    sign_in_and_2fa_user

    visit edit_phone_path
    fill_in 'Phone', with: ''
    click_button 'Update'

    expect(page).to have_content 'Please fill in this field.'
  end
end
