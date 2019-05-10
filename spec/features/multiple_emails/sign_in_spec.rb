require 'rails_helper'

feature 'sign in with any email address' do
  scenario 'signing in any email address' do
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)

    user = create(:user, :signed_up, :with_multiple_emails)

    email1, email2 = user.reload.email_addresses.map(&:email)

    signin(email1, user.password)
    click_submit_default

    expect(page).to have_current_path(account_path)

    first(:link, t('links.sign_out')).click

    signin(email2, user.password)
    click_submit_default

    expect(page).to have_current_path(account_path)
  end
end
