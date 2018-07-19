require 'rails_helper'

describe PhoneVerification do
  describe '#send_sms' do
    it 'makes a POST request to Twilio Verify endpoint' do
      PhoneVerification.adapter = FakeAdapter

      phone = '17873270143'
      headers = { 'X-Authy-API-Key' => 'secret' }
      locale = 'es'
      code = '123456'
      body = {
        code_length: 6,
        country_code: '1',
        custom_code: code,
        locale: locale,
        phone_number: '7873270143',
        via: 'sms',
      }
      connecttimeout = PhoneVerification::OPEN_TIMEOUT
      timeout = PhoneVerification::READ_TIMEOUT

      expect(FakeAdapter).to receive(:post).
        with(
          PhoneVerification::AUTHY_START_ENDPOINT,
          headers: headers,
          body: body,
          connecttimeout: connecttimeout,
          timeout: timeout
        ).and_return(FakeAdapter::SuccessResponse.new)

      PhoneVerification.new(phone: phone, locale: locale, code: code).send_sms
    end

    it 'raises VerifyError when response is not successful' do
      PhoneVerification.adapter = FakeAdapter
      phone = '17035551212'
      code = '123456'

      allow(FakeAdapter).to receive(:post).and_return(FakeAdapter::ErrorResponse.new)

      expect { PhoneVerification.new(phone: phone, code: code).send_sms }.to raise_error do |error|
        expect(error.code).to eq 60_033
        expect(error.message).to eq 'Invalid number'
        expect(error).to be_a(PhoneVerification::VerifyError)
      end
    end
  end
end
