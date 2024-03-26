require 'rails_helper'

RSpec.describe CreateNewDeviceAlert do
  let(:user) do
    create(
      :user, sign_in_new_device: IdentityConfig.store.
      new_device_alert_delay_in_minutes.minutes.ago
    )
  end
  describe '#perform' do
    it 'deletes user sign_in_new_device value' do
      CreateNewDeviceAlert.new.perform
      expect(user.sign_in_new_device).to eq(nil)
    end
  end
end
