require 'rails_helper'

describe PhoneVerification do
  describe '#send_sms' do
    let(:phone) { '17035551212' }
    let(:code) { '123456' }
    let(:verification) do
      PhoneVerification.new(phone: phone, code: code).send_sms
    end

    it 'does not raise an error when the response is successful' do
      PhoneVerification.adapter = FakeAdapter
      allow(FakeAdapter).to receive(:post).and_return(FakeAdapter::SuccessResponse.new)

      expect { verification }.to_not raise_error
    end

    it 'raises VerifyError when response is not successful' do
      PhoneVerification.adapter = FakeAdapter
      allow(FakeAdapter).to receive(:post).and_return(FakeAdapter::ErrorResponse.new)

      expect { verification }.to raise_error do |error|
        expect(error.code).to eq 60_033
        expect(error.message).to eq 'Invalid number'
        expect(error).to be_a(PhoneVerification::VerifyError)
      end
    end

    it 'raises VerifyError when response body is not valid JSON' do
      PhoneVerification.adapter = FakeAdapter
      allow(FakeAdapter).to receive(:post).and_return(FakeAdapter::EmptyResponse.new)

      expect { verification }.to raise_error do |error|
        expect(error.code).to eq 0
        expect(error.message).to eq ''
        expect(error.status).to eq 400
        expect(error.response).to eq ''
        expect(error).to be_a(PhoneVerification::VerifyError)
      end
    end

    it 'calls the Twilio/Authy Verify API with the right parameters' do
      PhoneVerification.adapter = Faraday.new(url: PhoneVerification::AUTHY_HOST)

      locale = 'fr'
      body = "code_length=6&country_code=1&custom_code=#{code}&locale=#{locale}&" \
             "phone_number=7035551212&via=sms"

      stub_request(:post, 'https://api.authy.com/protected/json/phones/verification/start').
        with(
          body: body,
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Content-Type' => 'application/x-www-form-urlencoded',
            'User-Agent' => 'Faraday v0.15.2',
            'X-Authy-Api-Key' => Figaro.env.twilio_verify_api_key,
          }
        ).
        to_return(status: 200, body: '', headers: {})

      PhoneVerification.new(phone: phone, code: code, locale: locale).send_sms
    end

    it 'rescues timeout errors, retries, then raises a custom Twilio error' do
      PhoneVerification.adapter = FakeAdapter
      expect(FakeAdapter).to receive(:post).twice.and_raise(Faraday::TimeoutError)

      expect { verification }.to raise_error do |error|
        expect(error.code).to eq 4_815_162_342
        expect(error.message).to eq 'Twilio Verify: Faraday::TimeoutError'
        expect(error.status).to eq 0
        expect(error.response).to eq ''
        expect(error).to be_a(PhoneVerification::VerifyError)
      end
    end

    it 'rescues failed connection errors, retries, then raises a custom Twilio error' do
      PhoneVerification.adapter = FakeAdapter
      expect(FakeAdapter).to receive(:post).twice.and_raise(Faraday::ConnectionFailed.new('error'))

      expect { verification }.to raise_error do |error|
        expect(error.code).to eq 4_815_162_342
        expect(error.message).to eq 'Twilio Verify: Faraday::ConnectionFailed'
        expect(error.status).to eq 0
        expect(error.response).to eq ''
        expect(error).to be_a(PhoneVerification::VerifyError)
      end
    end
  end
end
