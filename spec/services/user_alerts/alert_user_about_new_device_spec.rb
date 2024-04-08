require 'rails_helper'

RSpec.describe UserAlerts::AlertUserAboutNewDevice do
  describe '#call' do
    let(:user) { create(:user, :fully_registered) }
    let(:event) { create(:event, user:) }
    let(:disavowal_token) { 'the_disavowal_token' }
    let(:device) { create(:device, user: user) }

    context 'aggregated new device alerts enabled' do
      before do
        allow(IdentityConfig.store).to receive(
          :feature_new_device_alert_aggregation_enabled,
        ).and_return(true)
      end

      it 'sets the user sign_in_new_device_at value to time of the given event' do
        described_class.call(event:, device:, disavowal_token:)

        expect(user.sign_in_new_device_at).to be_present.and eq(event.created_at)
      end
    end

    context 'aggregated new device alerts disabled' do
      before do
        allow(IdentityConfig.store).to receive(
          :feature_new_device_alert_aggregation_enabled,
        ).and_return(false)
      end

      it 'sends an email to all confirmed email addresses' do
        user.email_addresses.destroy_all
        confirmed_email_addresses = create_list(:email_address, 2, user: user)
        create(:email_address, user: user, confirmed_at: nil)

        described_class.call(event:, device:, disavowal_token:)

        expect_delivered_email_count(2)
        expect_delivered_email(
          to: [confirmed_email_addresses[0].email],
          subject: t('user_mailer.new_device_sign_in.subject', app_name: APP_NAME),
          body: [disavowal_token],
        )
        expect_delivered_email(
          to: [confirmed_email_addresses[1].email],
          subject: t('user_mailer.new_device_sign_in.subject', app_name: APP_NAME),
          body: [disavowal_token],
        )
      end
    end
  end
end
