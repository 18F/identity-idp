require 'rails_helper'

describe SmsSenderNumberChangeJob do
  describe '.perform' do
    it 'sends number change message to the phone number', twilio: true do
      SmsSenderNumberChangeJob.perform_now('1234')

      messages = MockTwilioClient.messages

      expect(messages.size).to eq(1)
      msg = messages.first
      expect(msg.to).to eq('1234')
      expect(msg.body).to include('You have changed the phone number')
    end
  end
end
