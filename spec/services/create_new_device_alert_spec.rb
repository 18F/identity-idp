require 'rails_helper'

RSpec.describe CreateNewDeviceAlert do
  let(:user) { create(:user) }
  let(:now) { Time.zone.now }

  before do
    user.update! sign_in_new_device_at:
      now - 1 - IdentityConfig.store.new_device_alert_delay_in_minutes.minutes
  end

  describe '#perform' do
    it 'sends an email for matching user' do
      emails_sent = CreateNewDeviceAlert.new.perform(now)
      expect(emails_sent).to eq(1)
      email_sent_again = CreateNewDeviceAlert.new.perform(now)
      expect(email_sent_again).to eq(0)
    end

    it 'resets user sign_in_new_device_at to nil' do
      CreateNewDeviceAlert.new.perform(now)
      expect(user.reload.sign_in_new_device_at).to eq(nil)
    end

    it 'disregards a user with sign_in_new_device_at set to nil' do
      user.update! sign_in_new_device_at: nil
      emails_sent = CreateNewDeviceAlert.new.perform(now)
      expect(emails_sent).to eq(0)
    end

    it 'logs analytics with number of emails sent' do
      analytics = FakeAnalytics.new
      alert = CreateNewDeviceAlert.new
      allow(alert).to receive(:analytics).and_return(analytics)

      alert.perform(now)

      expect(analytics).to have_logged_event(:create_new_device_alert_job_emails_sent, count: 1)
    end
  end
end
