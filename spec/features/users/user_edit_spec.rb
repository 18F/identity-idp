require 'rails_helper'

feature 'User edit' do
  scenario 'user sees error message if form is submitted without email', js: true do
    sign_in_and_2fa_user

    visit manage_email_path
    fill_in 'Email', with: ''
    click_button 'Update'

    expect(page).to have_content t('valid_email.validations.email.invalid')
  end

  scenario 'user sees error message if form is submitted without phone number', js: true do
    sign_in_and_2fa_user

    visit manage_phone_path
    fill_in 'Phone', with: ''
    click_button 'Update'

    expect(page).to have_content t('errors.messages.improbable_phone')
  end
end
