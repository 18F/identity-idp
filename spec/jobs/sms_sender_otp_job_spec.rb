require 'rails_helper'

describe SmsSenderOtpJob, sms: true do
  describe '.perform' do
    it 'sends a message containing the OTP code to the mobile number' do
      SmsSenderOtpJob.perform_now('1234', '555-5555')

      expect(messages.size).to eq(1)
      msg = messages.first
      expect(msg.number).to eq('555-5555')
      expect(msg.body).to include('secure one-time password')
      expect(msg.body).to include('1234')
    end
  end
end
