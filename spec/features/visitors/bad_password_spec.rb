require 'rails_helper'

feature 'Visitor signs in with bad passwords and gets locked out' do
  let(:bad_email) { 'bad@email.com' }
  let(:bad_password) { 'badpassword' }

  scenario 'visitor signs in with too many bad passwords and gets locked out' do
    visit new_user_session_path
    error_message = t('devise.failure.invalid_html', link: t('devise.failure.invalid_link_text'))
    IdentityConfig.store.max_bad_passwords.times do
      fill_in_credentials_and_submit(bad_email, bad_password)
      expect(page).to have_content(error_message)
      expect(page).to have_current_path(new_user_session_path)
    end
    fill_in_credentials_and_submit(bad_email, bad_password)
    expect(page).to have_content(t('errors.sign_in.bad_password_limit'))
  end
end
