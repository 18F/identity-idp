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
      expect(user.sign_in_new_device_at).to eq(nil)
    end
  end
end
