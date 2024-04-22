require 'rails_helper'

RSpec.describe 'reset password with multiple emails', allowed_extra_analytics: [:*] do
  scenario 'it sends the reset instruction to the email the user enters' do
    user = create(:user, :with_multiple_emails)
    email1, email2 = user.reload.email_addresses.map(&:email)

    visit root_path
    click_link t('links.passwords.forgot')
    fill_in t('account.index.email'), with: email1
    click_button t('forms.buttons.continue')

    expect_delivered_email_count(1)
    expect_delivered_email(
      to: [email1],
      subject: t('user_mailer.reset_password_instructions.subject'),
    )

    Capybara.reset_session!

    visit root_path
    click_link t('links.passwords.forgot')
    fill_in t('account.index.email'), with: email2
    click_button t('forms.buttons.continue')

    expect_delivered_email_count(2)
    expect_delivered_email(
      to: [email2],
      subject: t('user_mailer.reset_password_instructions.subject'),
    )
  end

  scenario 'it sends the missing user email if the requested email is not confirmed' do
    user = create(:user, :with_multiple_emails)
    unconfirmed_email_address = user.reload.email_addresses.last
    unconfirmed_email_address.update!(confirmed_at: nil)

    visit root_path
    click_link t('links.passwords.forgot')
    fill_in t('account.index.email'), with: unconfirmed_email_address.email
    click_button t('forms.buttons.continue')

    expect_delivered_email_count(1)
    expect_delivered_email(
      to: [unconfirmed_email_address.email],
      subject: t('anonymous_mailer.password_reset_missing_user.subject'),
    )
  end
end
