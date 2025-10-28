require 'rails_helper'

RSpec.describe UserAlerts::AlertUserAboutMaxAttempts do
  let(:user) { create(:user, :fully_registered) }
  let(:event) { create(:event, user:) }
  let(:disavowal_token) { 'the_disavowal_token' }
  let(:device) { create(:device, user: user) }

  describe '.max_attempts_alerts' do
    let(:sign_in_new_device_at) { 3.minutes.ago }
    let(:user) { create(:user, :fully_registered, sign_in_new_device_at:) }

    subject(:result) do
      UserAlerts::AlertUserAboutMaxAttempts.max_attempts_alert(user:, disavowal_token:)
    end

    it 'sends mailer immediately once user reaches max attempts' do
      # Include sign-in before 2FA
      sign_in_before_2fa_event = create(
        :event,
        user:,
        event_type: :sign_in_before_2fa,
        created_at: sign_in_new_device_at,
      )

      # Include sign-in unsuccessful 2FA
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
end
