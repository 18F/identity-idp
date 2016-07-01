require 'rails_helper'

describe TwilioService do
  describe 'proxy configuration' do
    it 'ignores the proxy configuration if not set' do
      expect(Figaro.env).to receive(:proxy_addr).and_return(nil)
      expect(Twilio::REST::Client).to receive(:new).with(/sid(1|2)/, /token(1|2)/)

      TwilioService.new
    end

    it 'passes the proxy configuration if set' do
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

  describe 'performance testing mode' do
    it 'uses NullTwilioClient when pt_mode is on' do
      expect(FeatureManagement).to receive(:pt_mode?).and_return(true)
      expect(NullTwilioClient).to receive(:new)
      expect(Twilio::REST::Client).to_not receive(:new)

      TwilioService.new
    end

    it 'uses NullTwilioClient when pt_mode is true and proxy is set' do
      expect(FeatureManagement).to receive(:pt_mode?).and_return(true)
      allow(Figaro.env).to receive(:proxy_addr).and_return('123.456.789')

      expect(NullTwilioClient).to receive(:new)
      expect(Twilio::REST::Client).to_not receive(:new)

      TwilioService.new
    end

    it 'uses a real Twilio client when pt_mode is false' do
      expect(FeatureManagement).to receive(:pt_mode?).and_return(false)
      expect(Twilio::REST::Client).to receive(:new).with(/sid(1|2)/, /token(1|2)/)

      TwilioService.new
    end

    it 'does not send any OTP when pt_mode is true', sms: true do
      expect(FeatureManagement).to receive(:pt_mode?).at_least(:once).and_return(true)
      SmsSenderOtpJob.perform_now('1234', '555-5555')

      expect(messages.size).to eq 0
    end

    it 'sends an OTP when pt_mode is false', sms: true do
      expect(FeatureManagement).to receive(:pt_mode?).at_least(:once).and_return(false)
      SmsSenderOtpJob.perform_now('1234', '555-5555')

      expect(messages.size).to eq 1
    end

    it 'does not send a number change SMS when pt_mode is true', sms: true do
      expect(FeatureManagement).to receive(:pt_mode?).at_least(:once).and_return(true)
      SmsSenderNumberChangeJob.perform_now('555-5555')

      expect(messages.size).to eq 0
    end

    it 'sends number change SMS when pt_mode is false', sms: true do
      expect(FeatureManagement).to receive(:pt_mode?).at_least(:once).and_return(false)
      SmsSenderNumberChangeJob.perform_now('555-5555')

      expect(messages.size).to eq 1
    end
  end

  describe '#send_sms' do
    it 'sends an SMS from the number configured in the twilio_accounts config', sms: true do
      expect(Twilio::REST::Client).
        to receive(:new).with(/sid(1|2)/, /token(1|2)/).and_call_original

      twilio = TwilioService.new
      twilio.send_sms(
        to: '5555555555',
        body: '!!CODE1!!'
      )

      expect(messages.size).to eq(1)
      messages.each do |msg|
        expect(msg.from).to match(/(\+19999999999|\+12222222222)/)
        expect(msg.number).to eq('5555555555')
        expect(msg.body).to eq('!!CODE1!!')
      end
    end
  end

  describe '#account' do
    it 'randomly samples one of the accounts' do
      expect(TWILIO_ACCOUNTS).to include(TwilioService.new.account)
    end
  end
end
