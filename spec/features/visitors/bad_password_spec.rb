require 'rails_helper'

RSpec.feature 'Visitor signs in with bad passwords and gets locked out' do
  let(:bad_email) { 'bad@email.com' }
  let(:bad_password) { 'badpassword' }

  scenario 'visitor tries too many bad passwords gets locked out then waits window seconds' do
    visit new_user_session_path
    error_message = t(
      'devise.failure.invalid_html',
      link_html: t('devise.failure.invalid_link_text'),
    )
    IdentityConfig.store.max_bad_passwords.times do
      fill_in_credentials_and_submit(bad_email, bad_password)
      expect(page).to have_content(error_message)
      expect(page).to have_current_path(new_user_session_path)
    end
    2.times do
      fill_in_credentials_and_submit(bad_email, bad_password)
      expect(page).to have_content(t('errors.sign_in.bad_password_limit'))
    end
    travel_to(IdentityConfig.store.max_bad_passwords_window_in_seconds.seconds.from_now) do
      fill_in_credentials_and_submit(bad_email, bad_password)
      expect(page).to have_content(error_message)
    end
  end
end
