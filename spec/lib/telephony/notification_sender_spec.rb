# frozen_string_literal: true

require 'nokogiri'
require 'rails_helper'

RSpec.describe Telephony::NotificationSender do
  before do
    Telephony::Test::Message.clear_messages
    Telephony::Test::Call.clear_calls
  end

  context 'with the test adapter' do
    subject do
      described_class.new(
        message: message,
        to: to,
        expiration: expiration,
        channel: channel,
        domain: domain,
        country_code: country_code,
        extra_metadata: { phone_fingerprint: 'abc123' },
      )
    end

    let(:to) { '+1 (202) 262-1234' }
    let(:expiration) { 5 }
    let(:domain) { 'login.gov' }
    let(:country_code) { 'US' }
    let(:message) { 'free form message' }

    before do
      allow(Telephony.config).to receive(:adapter).and_return(:test)
    end

    context 'for SMS' do
      let(:channel) { :sms }

      it 'send the message as requested' do
        subject.send_notification

        expect(Telephony::Test::Message.messages[0].body).to eq(message)
      end

      it 'logs a message being sent' do
        expect(Telephony.config.logger).to receive(:info).with(
          {
            success: true,
            errors: {},
            request_id: 'fake-message-request-id',
            message_id: 'fake-message-id',
            phone_fingerprint: 'abc123',
            adapter: :test,
            channel: :sms,
            context: :authentication,
            country_code: 'US',
          }.to_json,
        )

        subject.send_notification
      end
    end

    context 'for Voice' do
      let(:channel) { :voice }

      it 'send the message as requested' do
        subject.send_notification

        expect(Telephony::Test::Call.calls[0].body).to include(message)
      end
    end
  end
end
