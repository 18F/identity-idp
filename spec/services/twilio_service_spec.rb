require 'rails_helper'

describe TwilioService do
  context 'when telephony is disabled' do
    before do
      expect(FeatureManagement).to receive(:telephony_disabled?).at_least(:once).and_return(true)
    end

    it 'uses NullTwilioClient' do
      TwilioService.telephony_service = Twilio::REST::Client

      client = instance_double(NullTwilioClient)
      expect(NullTwilioClient).to receive(:new).and_return(client)
      http_client = Struct.new(:adapter)
      expect(client).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:adapter=).with(:typhoeus)
      expect(Twilio::REST::Client).to_not receive(:new)

      TwilioService.new
    end

    it 'does not send OTP messages', twilio: true do
      TwilioService.telephony_service = FakeSms

      SmsOtpSenderJob.perform_now(
        code: '1234',
        phone: '555-5555',
        otp_created_at: Time.zone.now.to_s
      )

      expect(FakeSms.messages.size).to eq 0
    end
  end

  context 'when telephony is enabled' do
    before do
      expect(FeatureManagement).to receive(:telephony_disabled?).
        at_least(:once).and_return(false)
      TwilioService.telephony_service = Twilio::REST::Client
    end

    it 'uses a real Twilio client' do
      client = instance_double(Twilio::REST::Client)
      expect(Twilio::REST::Client).
        to receive(:new).with(/sid(1|2)/, /token(1|2)/).and_return(client)
      http_client = Struct.new(:adapter)
      expect(client).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:adapter=).with(:typhoeus)
      TwilioService.new
    end
  end

  describe '#phone_number' do
    it 'randomly samples one of the numbers' do
      expect(TWILIO_NUMBERS).to include(TwilioService.new.phone_number)
    end
  end

  describe '#place_call' do
    it 'initiates a phone call with options', twilio: true do
      TwilioService.telephony_service = FakeVoiceCall
      service = TwilioService.new

      service.place_call(
        to: '5555555555',
        url: 'https://twimlets.com/say?merp'
      )

      calls = FakeVoiceCall.calls
      expect(calls.size).to eq(1)
      msg = calls.first
      expect(msg.url).to eq('https://twimlets.com/say?merp')
      expect(msg.from).to match(/(\+19999999999|\+12222222222)/)
    end

    it 'partially redacts phone numbers embedded in error messages from Twilio' do
      TwilioService.telephony_service = FakeVoiceCall
      raw_message = 'Unable to create record: Account not authorized to call +123456789012.'
      error_code = '21215'
      status_code = 400
      sanitized_message = "[HTTP #{status_code}] #{error_code} : Unable to create record: Account " \
                          "not authorized to call +12345#######.\n\n"

      service = TwilioService.new

      raw_error = Twilio::REST::RestError.new(
        raw_message, FakeTwilioErrorResponse.new(error_code)
      )

      expect(service.send(:client).calls).to receive(:create).
        and_raise(raw_error)

      expect { service.place_call(to: '+123456789012', url: 'https://twimlet.com') }.
        to raise_error(Twilio::REST::RestError, sanitized_message)
    end
  end

  describe '#send_sms' do
    it 'sends an SMS with valid attributes', twilio: true do
      allow(Figaro.env).to receive(:twilio_messaging_service_sid).and_return('fake_sid')

      TwilioService.telephony_service = FakeSms
      service = TwilioService.new

      service.send_sms(
        to: '5555555555',
        body: '!!CODE1!!'
      )

      messages = FakeSms.messages
      expect(messages.size).to eq(1)
      messages.each do |msg|
        expect(msg.messaging_service_sid).to eq('fake_sid')
        expect(msg.to).to eq('5555555555')
        expect(msg.body).to eq('!!CODE1!!')
      end
    end

    it 'partially redacts phone numbers embedded in error messages from Twilio' do
      TwilioService.telephony_service = FakeSms
      raw_message = "The 'To' number +1 (888) 555-5555 is not a valid phone number"
      error_code = '21211'
      status_code = 400
      sanitized_message = "[HTTP #{status_code}] #{error_code} : The 'To' " \
                          "number +1 (888) 5##-#### is not a valid phone number\n\n"

      service = TwilioService.new
      raw_error = Twilio::REST::RestError.new(
        raw_message, FakeTwilioErrorResponse.new(error_code)
      )

      expect(service.send(:client).messages).to receive(:create).
        and_raise(raw_error)

      expect { service.send_sms(to: '+1 (888) 555-5555', body: 'test') }.
        to raise_error(Twilio::REST::RestError, sanitized_message)
    end
  end
end
