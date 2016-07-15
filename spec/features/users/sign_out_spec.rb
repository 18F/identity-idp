require 'rails_helper'

# Feature: Sign out
#   As a user
#   I want to sign out
#   So I can protect my account from unauthorized access
feature 'Sign out' do
  # Scenario: User signs out successfully
  #   Given I am signed in
  #   When I sign out
  #   Then I see a signed out message
  scenario 'user signs out successfully' do
    sign_in_and_2fa_user
    click_link(t('links.sign_out'))

    expect(page).to have_content t('devise.sessions.signed_out')
  end
end
