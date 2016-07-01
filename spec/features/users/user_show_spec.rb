require 'rails_helper'

# Feature: User profile page
#   As a user
#   I want to visit my user profile page
#   So I can see my personal account data
feature 'User profile page', devise: true do
  # Scenario: User attempts to see own profile
  #   Given I am signed in
  #   When I visit the show user page
  #   Then I receive an error
  xscenario 'user can not see own profile' do
    my_user = create(:user, :signed_up)
    user = sign_in_user(my_user)

    expect(page).
      to have_content t('devise.two_factor_authentication.header_text')

    fill_in 'code', with: user.direct_otp
    click_button 'Submit'

    visit user_path(user)

    expect(page.status_code).to eq(401)
    expect(page).to have_content t('upaya.errors.not_authorized')
  end

  # Scenario: User cannot see another user's profile
  #   Given I am signed in
  #   When I visit another user's profile
  #   Then I see an 'access denied' message
  xscenario "user cannot see another user's profile" do
    me = create(:user, :signed_up)
    other = create(:user, :signed_up, email: 'other@example.com')

    sign_in_and_2fa_user(me)
    Capybara.current_session.driver.header 'Referer', root_path
    visit user_path(other)

    expect(page.status_code).to eq(401)
    expect(page).to have_content t('upaya.errors.not_authorized')
  end
end
