describe Telephony::Test::VoiceSender do
  before do
    Telephony::Test::Call.clear_calls
  end

  describe '#send' do
    it 'adds the call to the call stack' do
      call_body = 'This is a test'
      phone = '+1 (202) 555-5000'

      response = subject.send(message: call_body, to: phone, country_code: 'US')

      last_call = Telephony::Test::Call.calls.last

      expect(last_call.body).to eq(call_body)
      expect(last_call.to).to eq(phone)
      expect(response.success?).to eq(true)
      expect(response.error).to eq(nil)
      expect(response.extra[:request_id]).to eq('fake-message-request-id')
    end

    it 'simulates a telephony error' do
      response = subject.send(message: 'test', to: '+1 (225) 555-1000', country_code: 'US')

      last_call = Telephony::Test::Call.calls.last

      expect(response.success?).to eq(false)
      expect(response.error).to eq(Telephony::TelephonyError.new('Simulated telephony error'))
      expect(response.extra[:request_id]).to eq('fake-message-request-id')
      expect(last_call).to eq(nil)
    end

    it 'simulates an invalid calling area error' do
      response = subject.send(message: 'test', to: '+1 (225) 555-2000', country_code: 'US')

      last_call = Telephony::Test::Call.calls.last

      expect(response.success?).to eq(false)
      expect(response.error).to eq(
        Telephony::InvalidCallingAreaError.new('Simulated calling area error'),
      )
      expect(response.extra[:request_id]).to eq('fake-message-request-id')
      expect(last_call).to eq(nil)
    end
  end
end
