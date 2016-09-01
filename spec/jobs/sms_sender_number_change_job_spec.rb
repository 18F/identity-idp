require 'rails_helper'

describe SmsSenderNumberChangeJob do
  describe '.perform' do
    it 'sends number change message to the phone number', twilio: true do
      TwilioService.telephony_service = FakeSms

      SmsSenderNumberChangeJob.perform_now('1234')

      messages = FakeSms.messages

      expect(messages.size).to eq(1)
      msg = messages.first
      expect(msg.from).to match(/(\+19999999999|\+12222222222)/)
      expect(msg.to).to eq('1234')
      expect(msg.body).to include('You have changed the phone number')
    end
  end
end
