require 'rails_helper'

# Feature: User index page
#   As a user
#   I want to see a list of users
#   So I can see who has registered
feature 'User index page', devise: true do
  # Scenario: Admin User listed on index page
  #   Given I am signed in
  #   When I visit the user index page
  #   Then I see my own email address
  xscenario 'admin sees own email address' do
    user = sign_in_and_2fa_admin

    visit users_path
    expect(page).to have_content user.email
  end

  # Scenario: User unable to see other users
  #   Given I am signed in
  #   When I visit the user index page
  #   Then I see access denied
  xscenario 'user disallowed seeing other users' do
    sign_in_and_2fa_user

    visit users_path
    expect(page.status_code).to eq(401)
  end

  # Scenario: Users are paginated
  #   Given I am signed in
  #   When I visit the user index page
  #   Then I see pagination links
  xscenario 'user sees pagination links' do
    30.times { FactoryGirl.create(:user, email: Faker::Internet.email) }
    sign_in_and_2fa_admin
    visit users_path

    expect(page).to have_css('.page.active', text: '1')
  end
end
