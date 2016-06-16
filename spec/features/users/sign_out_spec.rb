require 'rails_helper'

# Feature: Sign out
#   As a user
#   I want to sign out
#   So I can protect my account from unauthorized access
feature 'Sign out', devise: true do
  # Scenario: User signs out successfully
  #   Given I am signed in
  #   When I sign out
  #   Then I see a signed out message
  scenario 'user signs out successfully' do
    sign_in_user
    click_link(t('upaya.links.sign_out'))

    expect(page).to have_content t('devise.sessions.signed_out')
  end

  scenario 'user session times out before mobile has been confirmed' do
    user = sign_in_user
    user.update(unconfirmed_mobile: '555-555-5555')

    Timecop.freeze(Time.current + 1200) do
      visit edit_user_registration_path
      expect(user.reload.unconfirmed_mobile).to be_nil
    end
  end
end
