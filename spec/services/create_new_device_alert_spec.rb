require 'rails_helper'

RSpec.describe CreateNewDeviceAlert do
  let(:user) { create(:user) }
  describe '#perform' do
    let(:now) { Time.zone.now }
    context 'after waiting the full wait period' do
      it 'deletes user sign_in_new_device value' do
        before_waiting_the_full_wait_period(now) do
          user.sign_in_new_device = now - IdentityConfig.store.
            new_device_alert_delay_in_minutes.minutes
        end

        travel_to(now + IdentityConfig.store.new_device_alert_delay_in_minutes.minutes)
        CreateNewDeviceAlert.new.perform

        expect(user.sign_in_new_device).to eq(nil)
      end
    end
  end

  def before_waiting_the_full_wait_period(now)
    minutes = IdentityConfig.store.new_device_alert_delay_in_minutes.minutes
    travel_to(now - minutes) do
      yield
    end
  end
end
