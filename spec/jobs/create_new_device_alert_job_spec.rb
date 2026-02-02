require 'rails_helper'

RSpec.describe CreateNewDeviceAlertJob do
  let(:user) { create(:user) }
  let(:now) { Time.zone.now }
  let(:new_device_alert_window_start_in_minutes) { nil }
  let(:new_device_alert_delay_in_minutes) { 5 }
  let(:start_window) do
    if new_device_alert_window_start_in_minutes.nil?
      nil
    else
      now - new_device_alert_window_start_in_minutes.minutes
    end
  end
  let(:end_window) { now - new_device_alert_delay_in_minutes.minutes }

  before do
    allow(IdentityConfig.store).to receive(:new_device_alert_window_start_in_minutes)
      .and_return(new_device_alert_window_start_in_minutes)
    allow(IdentityConfig.store).to receive(:new_device_alert_delay_in_minutes)
      .and_return(new_device_alert_delay_in_minutes)
    user.update! sign_in_new_device_at: sign_in_new_device_at
  end

  describe '#perform' do
    context 'when new_device_alert_window_start_in_minutes is set' do
      let(:new_device_alert_window_start_in_minutes) { 15 }

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

    context 'when new_device_alert_window_start_in_minutes is nil' do
      let(:new_device_alert_window_start_in_minutes) { nil }

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

      context 'when sign_in_new_device_at is before the end window' do
        let(:sign_in_new_device_at) { end_window - rand(60).seconds }

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
end
