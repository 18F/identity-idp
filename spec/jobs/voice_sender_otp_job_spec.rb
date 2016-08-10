require 'rails_helper'

describe VoiceSenderOtpJob do
  describe '.perform' do
    it 'initiates the phone call to deliver the OTP', twilio: true do
      VoiceSenderOtpJob.perform_now('1234', '555-5555')

      calls = MockTwilioClient.calls
      code = '1234'.scan(/\d/).join(', ')
      message = t('voice.otp_confirmation', code: code)
      url_message = URI.escape(message)

      expect(calls.size).to eq(1)
      call = calls.first
      expect(call.to).to eq('555-5555')
      expect(call.url).to include(url_message)
    end
  end
end
