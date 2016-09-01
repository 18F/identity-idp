require 'rails_helper'

describe VoiceSenderOtpJob do
  describe '.perform' do
    it 'initiates the phone call to deliver the OTP', twilio: true do
      TwilioService.telephony_service = FakeVoiceCall

      VoiceSenderOtpJob.perform_now('1234', '555-5555')

      calls = FakeVoiceCall.calls

      code = '1234'.scan(/\d/).join(', ')
      message = t('voice.otp_confirmation', code: code)
      url_message = URI.escape(message)

      expect(calls.size).to eq(1)
      call = calls.first
      expect(call.to).to eq('555-5555')
      expect(call.url).to include(url_message)
      expect(call.from).to match(/(\+19999999999|\+12222222222)/)
    end
  end
end
