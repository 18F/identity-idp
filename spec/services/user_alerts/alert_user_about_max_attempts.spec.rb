RSpec.describe UserAlerts::AlertUserAboutNewDevice do
  let(:user) { create(:user, :fully_registered) }
  let(:event) { create(:event, user:) }
  let(:disavowal_token) { 'the_disavowal_token' }
  let(:device) { create(:device, user: user) }

  describe '.send_alert' do
    let(:sign_in_new_device_at) { 3.minutes.ago }
    let(:user) { create(:user, :fully_registered, sign_in_new_device_at:) }

    subject(:result) do
      UserAlerts::AlertUserAboutNewDevice.send_alert(user:, disavowal_token:)
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
