describe TwilioService, sms: true do
  describe 'proxy configuration' do
    it 'ignores the proxy configuration if not set' do
      expect(Figaro.env).to receive(:proxy_addr).and_return(nil)
      expect(Twilio::REST::Client).to receive(:new).with('sid', 'token')

      TwilioService.new
    end

    it 'passes the proxy configuration if set' do
      expect(Figaro.env).to receive(:proxy_addr).at_least(:once).and_return('123.456.789')
      expect(Figaro.env).to receive(:proxy_port).and_return('6000')

      expect(Twilio::REST::Client).to receive(:new).with(
        'sid',
        'token',
        proxy_addr: '123.456.789',
        proxy_port: '6000'
      )

      TwilioService.new
    end
  end

  describe 'test client', sms: true do
    let(:user) { build_stubbed(:user, otp_secret_key: 'lzmh6ekrnc5i6aaq') }

    it 'uses the test client when pt_mode is true' do
      expect(FeatureManagement).to receive(:pt_mode?).and_return(true)
      expect(Twilio::REST::Client).to receive(:new).with('test_sid', 'test_token')

      TwilioService.new
    end

    it 'uses the test client when pt_mode is true and proxy is set' do
      expect(FeatureManagement).to receive(:pt_mode?).and_return(true)
      allow(Figaro.env).to receive(:proxy_addr).and_return('123.456.789')

      expect(Twilio::REST::Client).to receive(:new).with('test_sid', 'test_token')

      TwilioService.new
    end

    it 'does not use the test client when pt_mode is false' do
      expect(FeatureManagement).to receive(:pt_mode?).and_return(false)
      expect(Twilio::REST::Client).to receive(:new).with('sid', 'token')

      TwilioService.new
    end

    it 'sends an OTP from the test number when pt_mode is true' do
      expect(FeatureManagement).to receive(:pt_mode?).at_least(:once).and_return(true)
      SmsSenderOtpJob.perform_now(user)

      expect(messages.first.from).to eq '+15005550006'
    end

    it 'sends an OTP from the real number when pt_mode is false' do
      expect(FeatureManagement).to receive(:pt_mode?).at_least(:once).and_return(false)
      SmsSenderOtpJob.perform_now(user)

      expect(messages.first.from).to eq '+19999999999'
    end

    it 'sends number change SMS from test # when pt_mode is true' do
      expect(FeatureManagement).to receive(:pt_mode?).at_least(:once).and_return(true)
      SmsSenderNumberChangeJob.perform_now(user)

      expect(messages.first.from).to eq '+15005550006'
    end

    it 'sends number change SMS from real # when pt_mode is false' do
      expect(FeatureManagement).to receive(:pt_mode?).at_least(:once).and_return(false)
      SmsSenderNumberChangeJob.perform_now(user)

      expect(messages.first.from).to eq '+19999999999'
    end
  end

  describe '#send_sms' do
    it 'uses the same account for every call in a single instance' do
      expect(Rails.application.secrets).to receive(:twilio_accounts).
        and_return([
          {
            'sid' => 'sid1',
            'auth_token' => 'token1',
            'number' => '1111111111'
          }])
      expect(Twilio::REST::Client).to receive(:new).with('sid1', 'token1').and_call_original

      twilio = TwilioService.new
      twilio.send_sms(
        to: '5555555555',
        body: '!!CODE1!!'
      )
      twilio.send_sms(
        to: '6666666666',
        body: '!!CODE2!!'
      )

      expect(messages.size).to eq(2)
      messages.each do |msg|
        expect(msg.from).to eq('+11111111111')
      end
    end

    it 'uses a different Twilio account for different instances' do
      expect(Rails.application.secrets).to receive(:twilio_accounts).
        and_return(
          [{
            'sid' => 'sid1',
            'auth_token' => 'token1',
            'number' => '1111111111'
          }],
          [{
            'sid' => 'sid2',
            'auth_token' => 'token2',
            'number' => '2222222222'
          }])

      expect(Twilio::REST::Client).to receive(:new).with('sid1', 'token1').and_call_original

      TwilioService.new.send_sms(
        to: '5555555555',
        body: '!!CODE1!!'
      )

      expect(messages.size).to eq(1)
      msg1 = messages.first
      expect(msg1.from).to eq('+11111111111')
      clear_messages

      expect(Twilio::REST::Client).to receive(:new).with('sid2', 'token2').and_call_original

      TwilioService.new.send_sms(
        to: '6666666666',
        body: '!!CODE2!!'
      )

      expect(messages.size).to eq(1)
      msg2 = messages.first
      expect(msg2.from).to eq('+12222222222')
    end
  end

  describe '.random_account' do
    context 'twilio_accounts setting is missing' do
      it 'falls back to using deprecated Twilio settings' do
        allow(Rails.application.secrets).to receive(:twilio_accounts).and_return(nil)

        expect(TwilioService.random_account).to eq(
          'sid' => 'sid',
          'auth_token' => 'token',
          'number' => '8888888888'
        )
      end
    end

    context 'twilio_accounts has multiple entries' do
      it 'randomly samples one of the accounts' do
        expect(Rails.application.secrets.twilio_accounts).to receive(:sample)

        TwilioService.random_account
      end
    end
  end
end
