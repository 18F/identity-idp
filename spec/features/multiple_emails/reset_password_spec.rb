require 'rails_helper'

describe 'reset password with multiple emails' do
  scenario 'it sends the reset instruction to the email the user enters' do
    user = create(:user, :with_multiple_emails)
    email1, email2 = user.reload.email_addresses.map(&:email)

    mail1 = double
    expect(mail1).to receive(:deliver_now)
    expect(UserMailer).to receive(:reset_password_instructions).
      with(email1, hash_including(:token)).
      and_return(mail1)

    visit root_path
    click_link t('links.passwords.forgot')
    fill_in 'Email', with: email1
    click_button t('forms.buttons.continue')

    Capybara.reset_session!

    mail2 = double
    expect(mail2).to receive(:deliver_now)
    expect(UserMailer).to receive(:reset_password_instructions).
      with(email2, hash_including(:token)).
      and_return(mail2)

    visit root_path
    click_link t('links.passwords.forgot')
    fill_in 'Email', with: email2
    click_button t('forms.buttons.continue')
  end
end
