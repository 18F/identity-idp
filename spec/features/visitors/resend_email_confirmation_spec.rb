require 'rails_helper'

RSpec.feature 'Visit requests confirmation instructions again during sign up' do
  let!(:user) { create(:user, :unconfirmed) }

  before(:each) do
    visit sign_up_email_path
  end

  scenario 'user can resend their confirmation instructions via email' do
    fill_in t('forms.registration.labels.email'), with: user.email
    check t('sign_up.terms', app_name: APP_NAME)
    click_submit_default

    expect(unread_emails_for(user.email)).to be_present
  end
end
