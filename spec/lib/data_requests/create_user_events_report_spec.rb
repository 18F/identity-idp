require 'rails_helper'

describe DataRequests::CreateUserEventsReport do
  describe '#call' do
    it 'returns an array of hashes representing the users events' do
      user = create(:user)
      event1 = create(:event, created_at: 1.day.ago, disavowed_at: 12.hours.ago, user: user)
      device = create(:device)
      _event2 = create(
        :event, event_type: :webauthn_key_added, device: device, ip: '1.2.3.4', user: user
      )

      result = described_class.new(user).call

      expect(result.length).to eq(2)

      expect(result.first[:event_name]).to eq(event1.event_type)
      expect(result.first[:date_time]).to be_within(1.second).of(event1.created_at)
      expect(result.first[:disavowed_at]).to be_within(1.second).of(event1.disavowed_at)

      expect(result.last[:event_name]).to eq('webauthn_key_added')
      expect(result.last[:ip]).to eq('1.2.3.4')
      expect(result.last[:user_agent]).to eq(device.user_agent)
      expect(result.last[:device_cookie]).to eq(device.cookie_uuid)
    end
  end
end
