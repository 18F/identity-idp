require 'rails_helper'

describe TwilioService::Sms::Request do
  let(:url) { 'https://example.com' }
  let(:params) { { Body: 'stop' } }
  let(:signature) { 'signature' }

  describe '#valid?' do
    context 'when message signature is invalid' do
      it 'returns false' do
        allow_any_instance_of(Twilio::Security::RequestValidator).to(
          receive(:validate).and_return(false)
        )

        message = described_class.new(url, params, signature)

        expect(message.valid?).to be false
      end
    end

    context 'when message signature is valid' do
      before do
        allow_any_instance_of(Twilio::Security::RequestValidator).to(
          receive(:validate).and_return(true)
        )
      end

      it 'returns false when message is empty' do
        empty_params = {}

        message = described_class.new(url, empty_params, signature)

        expect(message.valid?).to be false
      end

      it 'returns false when message is not a valid message type' do
        invalid_params = { Body: 'SPORK' }

        message = described_class.new(url, invalid_params, signature)

        expect(message.valid?).to be false
      end

      it 'returns false when message includes valid message type in sentence' do
        invalid_params = { Body: 'stop it' }

        message = described_class.new(url, invalid_params, signature)

        expect(message.valid?).to be false
      end

      it 'returns true when message is valid' do
        message = described_class.new(url, params, signature)

        expect(message.valid?).to be true
      end
    end
  end
end
