require 'rails_helper'

describe Telephony::Test::SmsSender do
  include_context 'telephony'

  before do
    Telephony::Test::Message.clear_messages
  end

  subject(:sms_sender) { Telephony::Test::SmsSender.new }

  describe '#send' do
    it 'adds the message to the message stack' do
      message_body = 'This is a test'
      phone = '+1 (202) 555-5000'

      response = subject.send(message: message_body, to: phone, country_code: 'US')

      last_message = Telephony::Test::Message.messages.last

      expect(response.success?).to eq(true)
      expect(response.error).to eq(nil)
      expect(response.extra[:request_id]).to eq('fake-message-request-id')
      expect(response.extra[:message_id]).to eq('fake-message-id')
      expect(last_message.body).to eq(message_body)
      expect(last_message.to).to eq(phone)
    end

    it 'simulates a telephony error' do
      response = subject.send(message: 'test', to: '+1 (225) 555-1000', country_code: 'US')

      last_message = Telephony::Test::Message.messages.last

      expect(response.success?).to eq(false)
      expect(response.error).to eq(Telephony::TelephonyError.new('Simulated telephony error'))
      expect(response.extra[:request_id]).to eq('fake-message-request-id')
      expect(last_message).to eq(nil)
    end

    it 'simulates an invalid phone number error' do
      response = subject.send(message: 'test', to: '+1 (225) 555-300', country_code: 'US')

      last_message = Telephony::Test::Message.messages.last
      pp response
      expect(response.success?).to eq(false)
      expect(response.error).to eq(
        Telephony::InvalidPhoneNumberError.new('Simulated phone number error'),
      )
      expect(response.extra[:request_id]).to eq('fake-message-request-id')
      expect(last_message).to eq(nil)
    end

    it 'simulates an invalid calling area error' do
      response = subject.send(message: 'test', to: '+1 (225) 555-2000', country_code: 'US')

      last_message = Telephony::Test::Message.messages.last

      expect(response.success?).to eq(false)
      expect(response.error).to eq(
        Telephony::InvalidCallingAreaError.new('Simulated calling area error'),
      )
      expect(response.extra[:request_id]).to eq('fake-message-request-id')
      expect(last_message).to eq(nil)
    end
  end

  describe '#phone_info' do
    subject(:phone_info) { sms_sender.phone_info(phone_number) }

    context 'with a phone number that does not generate errors' do
      let(:phone_number) { '+18888675309' }
      it 'has a successful response' do
        expect(phone_info.type).to eq(:mobile)
        expect(phone_info.carrier).to eq('Test Mobile Carrier')
        expect(phone_info.error).to be_nil
      end
    end

    context 'generating a voip phone number' do
      let(:phone_number) { '+12255552000' }
      it 'has an error response' do
        expect(phone_info.type).to eq(:voip)
        expect(phone_info.carrier).to eq('Test VOIP Carrier')
        expect(phone_info.error).to be_nil
      end
    end

    context 'generating an error response' do
      let(:phone_number) { '+12255551000' }
      it 'has an error response' do
        expect(phone_info.type).to eq(:unknown)
        expect(phone_info.carrier).to be_nil
        expect(phone_info.error).to be_kind_of(StandardError)
      end
    end
  end
end
