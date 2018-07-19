require 'rails_helper'

describe TwilioService::Sms::Response do
  let(:url) { 'https://example.com' }
  let(:params) { { Body: 'stop' } }
  let(:signature) { 'signature' }
  let(:request) { TwilioService::Sms::Request }

  before do
    allow_any_instance_of(Twilio::Security::RequestValidator).to(
      receive(:validate).and_return(true)
    )
  end

  describe '#reply' do
    let(:number) { '+1 202-555-1212' }

    it 'dispatches a message based on its type' do
      message = request.new(url, params, signature)
      response = described_class.new(message)

      expect(response).to receive(:stop)

      response.reply
    end

    it 'is case-insensitive' do
      message = request.new(url, { Body: 'STOP' }, signature)
      response = described_class.new(message)

      expect(response).to receive(:stop)

      response.reply
    end

    it 'calls stop with alternative words' do
      %w[cancel end quit unsubscribe].each do |stop_word|
        message = request.new(url, { Body: stop_word }, signature)
        response = described_class.new(message)

        expect(response).to receive(:stop)

        response.reply
      end
    end

    it 'calls stop and returns the appropriate message' do
      message = request.new(url, { Body: 'stop', From: number }, signature)
      response = described_class.new(message)
      expected = { to: number, body: t('sms.stop.message') }

      expect(response.reply).to eq(expected)
    end

    it 'calls help and returns the appropriate message' do
      message = request.new(url, { Body: 'help', From: number }, signature)
      response = described_class.new(message)
      expected = { to: number, body: t('sms.help.message') }

      expect(response.reply).to eq(expected)
    end
  end
end
