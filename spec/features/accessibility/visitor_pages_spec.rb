require 'rails_helper'
require 'axe-rspec'

RSpec.feature 'Accessibility on pages that do not require authentication', :js do
  scenario 'login / root path' do
    visit root_path

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario 'forgot password page' do
    visit new_user_password_path

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario 'new user start registration page' do
    visit new_user_session_path

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario 'new user registration page' do
    visit sign_up_email_path

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario 'new user cancel registration page' do
    visit sign_up_cancel_path

    expect_page_to_have_no_accessibility_violations(page)
  end
end
