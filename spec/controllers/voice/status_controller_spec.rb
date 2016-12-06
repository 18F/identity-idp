require 'rails_helper'

RSpec.describe Voice::StatusController do
  describe '#create' do
    it 'tracks voice analytics' do
      stub_analytics

      expect(@analytics).to receive(:track_event).with(
        Analytics::OTP_VOICE_STATUS,
        call_id: '1234',
        call_status: 'completed',
        api_version: '1.0',
        direction: 'outbound-api',
        to_city: 'Washington',
        to_state: 'DC',
        to_zip: '20500',
        to_country: 'USA',
        duration: 5
      )

      post :create,
           CallSid: '1234',
           CallStatus: 'completed',
           ApiVersion: '1.0',
           Direction: 'outbound-api',
           ToCity: 'Washington',
           ToState: 'DC',
           ToZip: '20500',
           ToCountry: 'USA',
           CallDuration: '5'
    end
  end
end
