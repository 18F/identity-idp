require 'rails_helper'

describe SmsSenderOtpJob do
  describe '.perform' do
    it 'sends a message containing the OTP code to the mobile number', twilio: true do
      TwilioService.telephony_service = FakeSms

      SmsSenderOtpJob.perform_now('1234', '555-5555')

      messages = FakeSms.messages

      expect(messages.size).to eq(1)

      msg = messages.first

      expect(msg.from).to match(/(\+19999999999|\+12222222222)/)
      expect(msg.to).to eq('555-5555')
      expect(msg.body).to include('one-time passcode')
      expect(msg.body).to include('1234')
    end
  end
end
