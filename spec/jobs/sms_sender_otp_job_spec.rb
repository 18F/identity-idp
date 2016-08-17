require 'rails_helper'

describe SmsSenderOtpJob do
  describe '.perform' do
    it 'sends a message containing the OTP code to the mobile number', twilio: true do
      SmsSenderOtpJob.perform_now('1234', '555-5555')

      messages = MockTwilioClient.messages
      expect(messages.size).to eq(1)
      msg = messages.first

      expect(msg.to).to eq('555-5555')
      expect(msg.body).to include('one-time passcode')
      expect(msg.body).to include('1234')
    end
  end
end
