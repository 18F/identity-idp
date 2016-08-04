require 'rails_helper'

describe VoiceSenderOtpJob do
  describe '.perform' do
    it 'initiates the phone call to deliver the OTP', twilio: true do
      VoiceSenderOtpJob.perform_now('1234', '555-5555')

      calls = MockTwilioClient.calls
      code = '1234'.scan(/\d/).join(', ')
      url_message = URI.escape('one time passcode is, ' + code)

      expect(calls.size).to eq(1)
      msg = calls.first
      expect(msg.to).to eq('555-5555')
      expect(msg.url).to include(url_message)
    end
  end
end
