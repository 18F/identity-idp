require 'rails_helper'

describe UserAlerts::AlertUserAboutAccountVerified do
  describe '#call' do
    let(:user) { create(:user, :signed_up) }
    let(:disavowal_token) { 'the_disavowal_token' }
    let(:device) { create(:device, user: user) }
    let(:date_time) { Time.zone.now }

    it 'sends an email to all confirmed email addresses' do
      create_list(:email_address, 2, user: user)
      create(:email_address, user: user, confirmed_at: nil)
      confirmed_email_addresses = user.confirmed_email_addresses

      described_class.call(
        user: user,
        date_time: date_time,
        sp_name: '',
        disavowal_token: disavowal_token,
      )

      expect_delivered_email_count(3)
      expect_delivered_email(
        0, {
          to: [confirmed_email_addresses[0].email],
          subject: t('user_mailer.account_verified.subject', sp_name: ''),
          body: [disavowal_token],
        }
      )
      expect_delivered_email(
        1, {
          to: [confirmed_email_addresses[1].email],
          subject: t('user_mailer.account_verified.subject', sp_name: ''),
          body: [disavowal_token],
        }
      )
      expect_delivered_email(
        2, {
          to: [confirmed_email_addresses[2].email],
          subject: t('user_mailer.account_verified.subject', sp_name: ''),
          body: [disavowal_token],
        }
      )
    end
  end
end
