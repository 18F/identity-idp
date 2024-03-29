require 'rails_helper'

RSpec.describe CreateNewDeviceAlert do
  let(:user) do
    create(
      :user,
      :fully_registered,
      sign_in_new_device_at: Time.zone.now - IdentityConfig.store.new_device_alert_delay_in_minutes.
                                              minutes,
    )
  end
  describe '#perform' do
    it 'deletes user sign_in_new_device_at value' do
      CreateNewDeviceAlert.new.perform

      expect(user.sign_in_new_device_at).to eq(nil)
    end
  end
end
