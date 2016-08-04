require 'rails_helper'

describe TwilioVoiceService do
  describe '#place_call' do
    it 'initiates a phone call with options', twilio: true do
      service = TwilioVoiceService.new

      service.place_call(
        to: '5555555555',
        url: 'https://twimlets.com/say?merp'
      )

      calls = MockTwilioClient.calls
      expect(calls.size).to eq(1)
      msg = calls.first
      expect(msg.url).to eq('https://twimlets.com/say?merp')
    end
  end
end
