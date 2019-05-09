require 'rails_helper'

feature 'sign in with any email address' do
  scenario 'signing in any email address' do
    user = create(:user, :signed_up)
    user_email = user.email_addresses.first.email

    signin(user_email, user.password)

    user_email = create(:email_address)

    user.email_addresses << user_email

    user.reload.email_addresses.map(&:email)

    signin(user_email, user.password)
  end
end
