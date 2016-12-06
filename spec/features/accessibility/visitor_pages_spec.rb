require 'rails_helper'
require 'axe/rspec'

feature 'Accessibility on pages that do not require authentication', :js do
  scenario 'contact page' do
    visit contact_path

    expect(page).to be_accessible
  end

  scenario 'login / root path' do
    visit root_path

    expect(page).to be_accessible
  end

  scenario 'forgot password page' do
    visit new_user_password_path

    expect(page).to be_accessible
  end

  scenario 'new user start registration page' do
    visit sign_up_start_path

    expect(page).to be_accessible
  end

  scenario 'new user registration page' do
    visit sign_up_email_path

    expect(page).to be_accessible
  end
end
