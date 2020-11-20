require 'rails_helper'
require 'axe/rspec'

feature 'Accessibility on pages that do not require authentication', :js do
  scenario 'login / root path' do
    visit root_path

    expect(page).to be_accessible.according_to :section508, :"best-practice"
    expect(page).to label_required_fields
    expect(page).to be_uniquely_titled
  end

  scenario 'forgot password page' do
    visit new_user_password_path

    expect(page).to be_accessible.according_to :section508, :"best-practice"
    expect(page).to label_required_fields
    expect(page).to be_uniquely_titled
  end

  scenario 'new user start registration page' do
    visit new_user_session_path

    expect(page).to be_accessible.according_to :section508, :"best-practice"
    expect(page).to label_required_fields
    expect(page).to be_uniquely_titled
  end

  scenario 'new user registration page' do
    visit sign_up_email_path

    expect(page).to be_accessible.according_to :section508, :"best-practice"
    expect(page).to label_required_fields
    expect(page).to be_uniquely_titled
  end

  scenario 'new user cancel registration page' do
    visit sign_up_cancel_path

    expect(page).to be_accessible.according_to :section508, :"best-practice"
    expect(page).to label_required_fields
    expect(page).to be_uniquely_titled
  end
end
