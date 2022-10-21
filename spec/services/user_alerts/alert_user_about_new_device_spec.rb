require 'rails_helper'

describe UserAlerts::AlertUserAboutNewDevice do
  describe '#call' do
    let(:user) { create(:user, :signed_up) }
    let(:disavowal_token) { 'the_disavowal_token' }
    let(:device) { create(:device, user: user) }

    it 'sends an email to all confirmed email addresses' do
      user.email_addresses.destroy_all
      confirmed_email_addresses = create_list(:email_address, 2, user: user)
      create(:email_address, user: user, confirmed_at: nil)

      described_class.call(user, device, disavowal_token)

      expect_delivered_email_count(2)
      expect_delivered_email(
        0, {
          to: [confirmed_email_addresses[0].email],
          subject: t('user_mailer.new_device_sign_in.subject', app_name: APP_NAME),
          body: [disavowal_token],
        }
      )
      expect_delivered_email(
        1, {
          to: [confirmed_email_addresses[1].email],
          subject: t('user_mailer.new_device_sign_in.subject', app_name: APP_NAME),
          body: [disavowal_token],
        }
      )
    end
  end
end
