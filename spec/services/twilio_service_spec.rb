require 'rails_helper'

describe TwilioService do
  describe 'proxy configuration' do
    it 'ignores the proxy configuration if not set' do
      TwilioService.telephony_service = Twilio::REST::Client

      expect(Figaro.env).to receive(:proxy_addr).and_return(nil)
      expect(Twilio::REST::Client).to receive(:new).with(/sid(1|2)/, /token(1|2)/)

      TwilioService.new
    end

    it 'passes the proxy configuration if set' do
      TwilioService.telephony_service = Twilio::REST::Client

      expect(Figaro.env).to receive(:proxy_addr).at_least(:once).and_return('123.456.789')
      expect(Figaro.env).to receive(:proxy_port).and_return('6000')

      expect(Twilio::REST::Client).to receive(:new).with(
        /sid(1|2)/,
        /token(1|2)/,
        proxy_addr: '123.456.789',
        proxy_port: '6000'
      )

      TwilioService.new
    end
  end

  context 'when telephony is disabled' do
    before do
      expect(FeatureManagement).to receive(:telephony_disabled?).at_least(:once).and_return(true)
    end

    it 'uses NullTwilioClient' do
      TwilioService.telephony_service = Twilio::REST::Client

      expect(NullTwilioClient).to receive(:new)
      expect(Twilio::REST::Client).to_not receive(:new)

      TwilioService.new
    end

    it 'uses NullTwilioClient when proxy is set' do
      TwilioService.telephony_service = Twilio::REST::Client

      allow(Figaro.env).to receive(:proxy_addr).and_return('123.456.789')

      expect(NullTwilioClient).to receive(:new)
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
      expect(Twilio::REST::Client).to receive(:new).with(/sid(1|2)/, /token(1|2)/)
      TwilioService.new
    end
  end

  describe '#account' do
    it 'randomly samples one of the accounts' do
      expect(TWILIO_ACCOUNTS).to include(TwilioService.new.account)
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

    it 'sanitizes phone numbers embedded in error messages from Twilio' do
      TwilioService.telephony_service = FakeVoiceCall
      raw_message = 'Account not authorized to call +12345.'
      error_code = '21211'
      status_code = 400
      sanitized_message = 'Account not authorized to call +#####.'

      service = TwilioService.new

      expect(service.send(:client).calls).to receive(:create).
        and_raise(Twilio::REST::RestError.new(raw_message, error_code, status_code))

      expect { service.place_call(to: '+1 (888) 555-5555', url: 'https://twimlet.com') }.
        to raise_error(Twilio::REST::RestError, sanitized_message)
    end
  end

  describe '#send_sms' do
    it 'sends an SMS with valid attributes', twilio: true do
      TwilioService.telephony_service = FakeSms
      service = TwilioService.new

      service.send_sms(
        to: '5555555555',
        body: '!!CODE1!!'
      )

      messages = FakeSms.messages
      expect(messages.size).to eq(1)
      messages.each do |msg|
        expect(msg.from).to match(/(\+19999999999|\+12222222222)/)
        expect(msg.to).to eq('5555555555')
        expect(msg.body).to eq('!!CODE1!!')
      end
    end

    it 'sanitizes phone numbers embedded in error messages from Twilio' do
      TwilioService.telephony_service = FakeSms
      raw_message = "The 'To' number +1 (888) 555-5555 is not a valid phone number"
      error_code = '21211'
      status_code = 400
      sanitized_message = "The 'To' number +# (###) ###-#### is not a valid phone number"

      service = TwilioService.new

      expect(service.send(:client).messages).to receive(:create).
        and_raise(Twilio::REST::RestError.new(raw_message, error_code, status_code))

      expect { service.send_sms(to: '+1 (888) 555-5555', body: 'test') }.
        to raise_error(Twilio::REST::RestError, sanitized_message)
    end
  end
end
