require 'rails_helper'

describe UserAlerts::AlertUserAboutPasswordChange do
  describe '#call' do
    it 'sends an email to all of the users confirmed email addresses' do
      user = create(:user)
      disavowal_token = 'asdf1234'
      user.email_addresses.destroy_all
      confirmed_email_addresses = create_list(:email_address, 2, user: user)
      create(:email_address, user: user, confirmed_at: nil)

      described_class.call(user, disavowal_token)

      expect_delivered_email_count(2)
      expect_delivered_email(
        to: [confirmed_email_addresses[0].email],
        subject: t('devise.mailer.password_updated.subject'),
        body: [disavowal_token],
      )
      expect_delivered_email(
        to: [confirmed_email_addresses[1].email],
        subject: t('devise.mailer.password_updated.subject'),
        body: [disavowal_token],
      )
    end
  end
end
