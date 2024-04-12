require 'rails_helper'

RSpec.describe UserAlerts::AlertUserAboutNewDevice do
  let(:user) { create(:user, :fully_registered) }
  let(:event) { create(:event, user:) }
  let(:disavowal_token) { 'the_disavowal_token' }
  let(:device) { create(:device, user: user) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe '.call' do
    context 'aggregated new device alerts enabled' do
      before do
        allow(IdentityConfig.store).to receive(
          :feature_new_device_alert_aggregation_enabled,
        ).and_return(true)
      end

      it 'sets the user sign_in_new_device_at value to time of the given event' do
        described_class.call(event:, device:, disavowal_token:)

        expect(user.sign_in_new_device_at.change(usec: 0)).to be_present.
          and eq(event.created_at.change(usec: 0))
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

  describe '.send_alert' do
    let(:sign_in_new_device_at) { 10.minutes.ago }
    let(:user) { create(:user, :fully_registered, sign_in_new_device_at:) }
    let(:disavowal_event) do
      create(:event, user:, event_type: :sign_in_after_2fa, created_at: 5.minutes.ago)
    end

    subject(:result) do
      UserAlerts::AlertUserAboutNewDevice.send_alert(user:, disavowal_event:, disavowal_token:)
    end

    it 'returns true' do
      expect(result).to eq(true)
    end

    it 'unsets sign_in_new_device_at on the user' do
      expect { result }.to change { user.reload.sign_in_new_device_at&.change(usec: 0) }.
        from(sign_in_new_device_at.change(usec: 0)).
        to(nil)
    end

    context 'with sign in notification expired disavowal event' do
      let(:disavowal_event) do
        create(
          :event,
          user:,
          event_type: :sign_in_notification_timeframe_expired,
          created_at: 5.minutes.ago,
        )
      end

      it 'sends mailer for authentication events within the time window' do
        # 1. Exclude events outside the timeframe, e.g. previous sign-in
        create(:event, user:, event_type: :sign_in_after_2fa, created_at: 11.minutes.ago)

        # 2. Include authentication events inside the timeframe, inclusive

        # 2.1 Include sign-in before 2FA
        sign_in_before_2fa_event = create(
          :event,
          user:,
          event_type: :sign_in_before_2fa,
          created_at: sign_in_new_device_at,
        )

        # 2.2 Include sign-in unsuccessful 2FA
        sign_in_unsuccessful_2fa_event = create(
          :event,
          user:,
          event_type: :sign_in_unsuccessful_2fa,
          created_at: 8.minutes.ago,
        )

        # 3. Exclude sign in notification timeframe expired event
        disavowal_event

        delivery = instance_double(ActionMailer::MessageDelivery)
        expect(delivery).to receive(:deliver_now_or_later)
        mailer = instance_double(UserMailer)
        expect(UserMailer).to receive(:with).and_return(mailer)
        expect(mailer).to receive(:new_device_sign_in_before_2fa).with(
          events: [
            sign_in_before_2fa_event,
            sign_in_unsuccessful_2fa_event,
          ],
          disavowal_token:,
        ).and_return(delivery)

        result
      end
    end

    context 'with sign in after 2fa disavowal event' do
      let(:disavowal_event) do
        create(:event, user:, event_type: :sign_in_after_2fa, created_at: 5.minutes.ago)
      end

      it 'sends mailer for authentication events within the time window' do
        # 1. Exclude events outside the timeframe, e.g. previous sign-in
        create(:event, user:, event_type: :sign_in_after_2fa, created_at: 11.minutes.ago)

        # 2. Include authentication events inside the timeframe, inclusive

        # 2.1 Include sign-in before 2FA
        sign_in_before_2fa_event = create(
          :event,
          user:,
          event_type: :sign_in_before_2fa,
          created_at: sign_in_new_device_at,
        )

        # 2.2 Include sign-in unsuccessful 2FA
        sign_in_unsuccessful_2fa_event = create(
          :event,
          user:,
          event_type: :sign_in_unsuccessful_2fa,
          created_at: 8.minutes.ago,
        )

        # 2.3 Include sign-in after 2FA
        sign_in_after_2fa_event = disavowal_event

        # 3. Exclude events not related to authentication, e.g. actions after sign-in
        create(:event, user:, event_type: :password_changed, created_at: 4.minutes.ago)

        # delivery = instance_double(ActionMailer::MessageDelivery)
        # expect(delivery).to receive(:deliver_now_or_later)
        # mailer = instance_double(UserMailer)
        # expect(UserMailer).to receive(:with).and_return(mailer)
        # expect(mailer).to receive(:new_device_sign_in_after_2fa).with(
        #   events: [
        #     sign_in_before_2fa_event,
        #     sign_in_unsuccessful_2fa_event,
        #     sign_in_after_2fa_event,
        #   ],
        #   disavowal_token:,
        # ).and_return(delivery)

        expect do
          result
        end.to have_enqueued_mail(UserMailer, :new_device_sign_in_after_2fa).with(
          params: { user: user.reload, email_address: user.email_addresses.first },
          args: [{
            events: [
              sign_in_before_2fa_event.reload,
              sign_in_unsuccessful_2fa_event.reload,
              sign_in_after_2fa_event.reload,
            ],
            disavowal_token: disavowal_token,
          }],
        )
      end
    end

    context 'without new device timestamp' do
      let(:sign_in_new_device_at) { nil }

      it 'returns false and does not send email' do
        expect(UserMailer).not_to receive(:with)

        expect(result).to eq(false)
      end
    end
  end
end
