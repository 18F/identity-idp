require 'rails_helper'

describe SmsResponder do
  describe '#call' do
    let(:message_body) { 'JOIN' }
    let(:message_from) { '+1 (202) 555-5000' }
    let(:params) do
      { Body: message_body, From: message_from, MessageSid: '123abc', FromCountry: 'US' }
    end
    let(:url) { 'http://example.com' }
    let(:signature) { 'fake-signautre' }
    let(:signature_valid) { true }
    let(:extra_analytics_attributes) { { message_sid: '123abc', from_country: 'US' } }

    subject { described_class.new(url, params, signature) }

    before do
      fake_validator = instance_double(Twilio::Security::RequestValidator)
      allow(fake_validator).to receive(:validate).
        with(url, params, signature).
        and_return(signature_valid)
      allow(Twilio::Security::RequestValidator).to receive(:new).
        with(Figaro.env.twilio_auth_token).
        and_return(fake_validator)
    end

    context 'for a join message' do
      it 'returns a successful response and sends an SMS' do
        expect(Telephony).to receive(:send_join_keyword_response).with(to: message_from)

        result = subject.call

        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
        expect(result.extra).to eq(extra_analytics_attributes)
      end
    end

    context 'for a help message' do
      let(:message_body) { 'Help' }

      it 'returns a successful response and sends an SMS' do
        expect(Telephony).to receive(:send_help_keyword_response).with(to: message_from)

        result = subject.call

        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
        expect(result.extra).to eq(extra_analytics_attributes)
      end
    end

    context 'for a stop message' do
      let(:message_body) { 'stop' }

      it 'returns a successful response and sends an SMS' do
        expect(Telephony).to receive(:send_stop_keyword_response).with(to: message_from)

        result = subject.call

        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
        expect(result.extra).to eq(extra_analytics_attributes)
      end
    end

    context 'for a message that does not need a response' do
      let(:message_body) { 'hello' }

      it 'returns an unsuccessful response and does not send an SMS' do
        result = subject.call

        expect(result.success?).to eq(false)
        expect(result.errors[:base]).to eq('The message does not need a response')
        expect(result.extra).to eq(extra_analytics_attributes)
      end
    end

    context 'when the signature is invalid' do
      let(:signature_valid) { false }

      it 'returns an unsuccessful response and does not send an SMS' do
        result = subject.call

        expect(result.success?).to eq(false)
        expect(result.errors[:base]).to eq('The inbound Twilio SMS message failed validation')
        expect(result.extra).to eq(extra_analytics_attributes)
        expect(Telephony::Test::Message.messages.length).to eq(0)
      end
    end
  end
end
