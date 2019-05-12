require 'rails_helper'

feature 'managing email address' do
  context 'show one email address if only one is configured' do

    scenario 'shows one email address for a user with only one' do
      user = create(:user, :with_authentication_app, :with_phone)
      sign_in_and_2fa_user(user)

      expect(page).to have_content(user.email_addresses.first.email)
    end

    scenario 'shows all email address for a user with multiple emails' do
      user = create(:user, :with_authentication_app, :with_phone)
      create(:email_address, user: user)
      email1, email2 = user.reload.email_addresses.map(&:email)
      sign_in_and_2fa_user(user)

      expect(page).to have_content(email1)
      expect(page).to have_content(email2)
    end
  end
end
