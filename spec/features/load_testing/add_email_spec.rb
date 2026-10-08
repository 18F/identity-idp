require 'rails_helper'

RSpec.feature 'Add email' do
  let(:email) { 'new-address@example.com' }

  scenario 'Load testing feature is on' do
    allow(IdentityConfig.store).to receive(:enable_load_testing_mode).and_return(true)
    user = create(:user, :fully_registered)
    original_email = user.email_addresses.first.email
    sign_in_and_2fa_user(user)

    visit add_email_path
    fill_in t('forms.registration.labels.email'), with: email
    click_button t('forms.buttons.submit.default')

    expect(page).to have_current_path(add_email_verify_email_path)

    click_link('CONFIRM NOW')

    expect(page).to have_current_path(account_path)
    expect(page).to have_content(t('devise.confirmations.confirmed'))

    # The link must take the real add-email confirmation path, which actually
    # confirms the address and sends the notification emails.
    expect(EmailAddress.where(user_id: user.id).find_with_email(email).confirmed_at)
      .to be_present
    expect_delivered_email(
      to: [original_email],
      subject: t('user_mailer.email_added.subject'),
    )
    expect_delivered_email(
      to: [email],
      subject: t('user_mailer.email_added.subject'),
    )
  end
end
