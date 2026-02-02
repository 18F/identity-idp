require 'rails_helper'

RSpec.describe CreateNewDeviceAlertJob do
  let(:user) { create(:user) }
  let(:now) { Time.zone.now }
  let(:start_window) { now - 15.minutes }
  let(:end_window) { now - 5.minutes }

  before do
    allow(IdentityConfig.store).to receive(:new_device_alert_window_start_in_minutes)
      .and_return(15)
    allow(IdentityConfig.store).to receive(:new_device_alert_delay_in_minutes)
      .and_return(5)
    user.update! sign_in_new_device_at: sign_in_new_device_at
  end

  describe '#perform' do
    context 'when sign_in_new_device_at is nil' do
      let(:sign_in_new_device_at) { nil }

      it 'disregards the user' do
        emails_sent = CreateNewDeviceAlertJob.new.perform(now)
        expect(emails_sent).to eq(0)
      end
    end

    context 'when sign_in_new_device_at is after queried time window' do
      let(:sign_in_new_device_at) { end_window + 1.second }

      it 'disregards the user' do
        emails_sent = CreateNewDeviceAlertJob.new.perform(now)
        expect(emails_sent).to eq(0)
      end
    end

    context 'when sign_in_new_device_at is before queried time window' do
      let(:sign_in_new_device_at) { start_window - 1.second }

      it 'disregards the user' do
        emails_sent = CreateNewDeviceAlertJob.new.perform(now)
        expect(emails_sent).to eq(0)
      end
    end

    context 'when sign_in_new_device_at is within the queried time window' do
      let(:sign_in_new_device_at) { rand(start_window..end_window) }

      it 'sends an email for matching user' do
        emails_sent = CreateNewDeviceAlertJob.new.perform(now)
        expect(emails_sent).to eq(1)
        email_sent_again = CreateNewDeviceAlertJob.new.perform(now)
        expect(email_sent_again).to eq(0)
      end

      it 'resets user sign_in_new_device_at to nil' do
        CreateNewDeviceAlertJob.new.perform(now)
        expect(user.reload.sign_in_new_device_at).to eq(nil)
      end

      it 'logs analytics with number of emails sent' do
        analytics = FakeAnalytics.new
        alert = CreateNewDeviceAlertJob.new
        allow(alert).to receive(:analytics).and_return(analytics)

        alert.perform(now)

        expect(analytics).to have_logged_event(:create_new_device_alert_job_emails_sent, count: 1)
      end
    end
  end
end
