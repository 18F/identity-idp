require 'rails_helper'

describe 'reset password with multiple emails' do
  scenario 'it sends the reset instruction to the email the user enters' do
    user = create(:user, :with_multiple_emails)
    email1, email2 = user.reload.email_addresses.map(&:email)

    mail1 = double
    expect(mail1).to receive(:deliver_now_or_later)
    expect(UserMailer).to receive(:reset_password_instructions).
      with(user, email1, hash_including(:token)).
      and_return(mail1)

    visit root_path
    click_link t('links.passwords.forgot')
    fill_in 'Email', with: email1
    click_button t('forms.buttons.continue')

    Capybara.reset_session!

    mail2 = double
    expect(mail2).to receive(:deliver_now_or_later)
    expect(UserMailer).to receive(:reset_password_instructions).
      with(user, email2, hash_including(:token)).
      and_return(mail2)

    visit root_path
    click_link t('links.passwords.forgot')
    fill_in 'Email', with: email2
    click_button t('forms.buttons.continue')
  end

  scenario 'it sends the unconfirmed address email if the requested email is not confirmed' do
    user = create(:user, :with_multiple_emails)
    unconfirmed_email_address = user.reload.email_addresses.last
    unconfirmed_email_address.update!(confirmed_at: nil)

    create_account_instructions_text = I18n.t(
      'user_mailer.email_confirmation_instructions.first_sentence.forgot_password',
      app_name: APP_NAME,
    )

    mail = double
    expect(mail).to receive(:deliver_now_or_later)
    expect(UserMailer).to receive(:unconfirmed_email_instructions).with(
      instance_of(User),
      unconfirmed_email_address.email,
      instance_of(String),
      hash_including(instructions: create_account_instructions_text),
    ).and_return(mail)

    visit root_path
    click_link t('links.passwords.forgot')
    fill_in 'Email', with: unconfirmed_email_address.email
    click_button t('forms.buttons.continue')
  end
end
