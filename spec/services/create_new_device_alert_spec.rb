require 'rails_helper'

RSpec.describe CreateNewDeviceAlert do
  let(:user) { create(:user) }
  describe '#perform' do
    before do
      allow(user).to receive(:sign_in_new_device_at).and_return(
        Time.zone.now,
      )
    end
    it 'deletes user sign_in_new_device_at value' do
      travel_to(IdentityConfig.store.new_device_alert_delay_in_minutes.minutes.from_now) do
        CreateNewDeviceAlert.new.perform
        expect(user.sign_in_new_device_at).to eq(nil)
      end
    end
  end
end
