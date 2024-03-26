require 'rails_helper'

RSpec.describe CreateNewDeviceAlert do
  let(:user) { create(:user, :fully_registered) }

  before do
    user.sign_in_new_device = Time.zone.now - IdentityConfig.store.new_device_alert_delay_in_minutes.minutes
  end
  describe '#perform' do
    it 'deletes user sign_in_new_device value' do
      travel_to(Time.zone.now + 5.minutes)
      described_class.new.perform

      expect(user.sign_in_new_device).to eq(nil)
    end
  end
end
