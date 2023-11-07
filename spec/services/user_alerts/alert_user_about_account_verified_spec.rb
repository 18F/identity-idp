require 'rails_helper'

RSpec.describe UserAlerts::AlertUserAboutAccountVerified do
  describe '#call' do
    let(:user) { create(:user, :fully_registered) }
    let(:device) { create(:device, user:) }
    let(:date_time) { Time.zone.now }

    it 'sends an email to all confirmed email addresses' do
      create_list(:email_address, 2, user:)
      create(:email_address, user:, confirmed_at: nil)
      confirmed_email_addresses = user.confirmed_email_addresses

      described_class.call(
        user:,
        date_time:,
        sp_name: '',
      )

      expect_delivered_email_count(3)
      expect_delivered_email(
        to: [confirmed_email_addresses[0].email],
        subject: t('user_mailer.account_verified.subject', sp_name: ''),
      )
      expect_delivered_email(
        to: [confirmed_email_addresses[1].email],
        subject: t('user_mailer.account_verified.subject', sp_name: ''),
      )
      expect_delivered_email(
        to: [confirmed_email_addresses[2].email],
        subject: t('user_mailer.account_verified.subject', sp_name: ''),
      )
    end
  end
end
