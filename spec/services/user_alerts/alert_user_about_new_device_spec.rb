require 'rails_helper'

RSpec.describe UserAlerts::AlertUserAboutNewDevice do
  let(:user) { create(:user, :fully_registered) }
  let(:event) { create(:event, user:) }
  let(:disavowal_token) { 'the_disavowal_token' }
  let(:device) { create(:device, user: user) }

  describe '.schedule_alert' do
    subject(:result) { described_class.schedule_alert(event:) }

    it 'sets the user sign_in_new_device_at value to time of the given event' do
      expect { result }.to change { user.reload.sign_in_new_device_at&.change(usec: 0) }
        .from(nil)
        .to(event.created_at.change(usec: 0))
    end
  end

  describe '.send_alert' do
    let(:sign_in_new_device_at) { 3.minutes.ago }
    let(:user) { create(:user, :fully_registered, sign_in_new_device_at:) }
    let(:disavowal_event) do
      create(:event, user:, event_type: :sign_in_after_2fa, created_at: 5.minutes.ago)
    end

    subject(:result) do
      UserAlerts::AlertUserAboutNewDevice.send_alert(user:, disavowal_event:, disavowal_token:)
    end

    before do
      allow(IdentityConfig.store).to receive(:new_device_alert_delay_in_minutes).and_return(5)
    end

    it 'returns true' do
      expect(result).to eq(true)
    end

    it 'unsets sign_in_new_device_at on the user' do
      expect { result }.to change { user.reload.sign_in_new_device_at&.change(usec: 0) }
        .from(sign_in_new_device_at.change(usec: 0))
        .to(nil)
    end

    context 'with sign in notification expired disavowal event' do
      let(:disavowal_event) do
        create(
          :event,
          user:,
          event_type: :sign_in_notification_timeframe_expired,
          created_at: Time.zone.now,
        )
      end

      it 'sends mailer for authentication events within the time window' do
        # 1. Exclude events outside possible window of time of recurring job run
        create(:event, user:, event_type: :sign_in_after_2fa, created_at: 16.minutes.ago)

        # 2. Exclude events outside the timeframe, e.g. previous sign-in
        create(:event, user:, event_type: :sign_in_after_2fa, created_at: 4.minutes.ago)

        # 3. Include authentication events inside the timeframe, inclusive

        # 3.1 Include sign-in before 2FA
        sign_in_before_2fa_event = create(
          :event,
          user:,
          event_type: :sign_in_before_2fa,
          created_at: sign_in_new_device_at,
        )

        # 3.2 Include sign-in unsuccessful 2FA
        sign_in_unsuccessful_2fa_event = create(
          :event,
          user:,
          event_type: :sign_in_unsuccessful_2fa,
          created_at: 2.minutes.ago,
        )

        # 4. Exclude sign in notification timeframe expired event
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
        create(:event, user:, event_type: :sign_in_after_2fa, created_at: 1.minute.ago)
      end

      it 'sends mailer for authentication events within the time window' do
        # 1. Exclude events outside possible window of time of recurring job run
        create(:event, user:, event_type: :sign_in_after_2fa, created_at: 16.minutes.ago)

        # 2. Exclude events outside the timeframe, e.g. previous sign-in
        create(:event, user:, event_type: :sign_in_after_2fa, created_at: 4.minutes.ago)

        # 3. Include authentication events inside the timeframe, inclusive

        # 3.1 Include sign-in before 2FA
        sign_in_before_2fa_event = create(
          :event,
          user:,
          event_type: :sign_in_before_2fa,
          created_at: sign_in_new_device_at,
        )

        # 3.2 Include sign-in unsuccessful 2FA
        sign_in_unsuccessful_2fa_event = create(
          :event,
          user:,
          event_type: :sign_in_unsuccessful_2fa,
          created_at: 2.minutes.ago,
        )

        # 3.3 Include sign-in after 2FA
        sign_in_after_2fa_event = disavowal_event

        # 4. Exclude events not related to authentication, e.g. actions after sign-in
        create(:event, user:, event_type: :password_changed, created_at: 30.seconds.ago)

        delivery = instance_double(ActionMailer::MessageDelivery)
        expect(delivery).to receive(:deliver_now_or_later)
        mailer = instance_double(UserMailer)
        expect(UserMailer).to receive(:with).and_return(mailer)
        expect(mailer).to receive(:new_device_sign_in_after_2fa).with(
          events: [
            sign_in_before_2fa_event,
            sign_in_unsuccessful_2fa_event,
            sign_in_after_2fa_event,
          ],
          disavowal_token:,
        ).and_return(delivery)

        result
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
