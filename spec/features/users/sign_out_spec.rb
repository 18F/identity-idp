require 'rails_helper'

feature 'Sign out' do
  scenario 'user signs out successfully' do
    sign_in_and_2fa_user
    click_link(t('links.sign_out'), match: :first)

    expect(page).to have_content t('devise.sessions.signed_out')
  end
end
