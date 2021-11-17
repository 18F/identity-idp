require 'nokogiri'
require 'rails_helper'

RSpec.describe Telephony::OtpSender do
  before do
    Telephony::Test::Message.clear_messages
    Telephony::Test::Call.clear_calls
  end

  context 'with the test adapter' do
    subject do
      described_class.new(
        to: to,
        otp: otp,
        expiration: expiration,
        channel: channel,
        domain: domain,
        country_code: country_code,
      )
    end

    let(:to) { '+1 (202) 262-1234' }
    let(:otp) { '123456' }
    let(:expiration) { 5 }
    let(:domain) { 'login.gov' }
    let(:country_code) { 'US' }

    before do
      allow(Telephony.config).to receive(:adapter).and_return(:test)
    end

    context 'for SMS' do
      let(:channel) { :sms }

      it 'saves the OTP that was sent for authentication' do
        subject.send_authentication_otp

        expect(Telephony::Test::Message.last_otp).to eq(otp)
      end

      it 'saves the OTP that was sent for confirmation' do
        subject.send_confirmation_otp

        expect(Telephony::Test::Message.last_otp).to eq(otp)
      end
    end

    context 'for Voice' do
      let(:channel) { :voice }

      it 'saves the OTP that was sent for authentication' do
        subject.send_authentication_otp

        expect(Telephony::Test::Call.last_otp).to eq(otp)
      end

      it 'saves the OTP that was sent for confirmation' do
        subject.send_confirmation_otp

        expect(Telephony::Test::Call.last_otp).to eq(otp)
      end
    end
  end

  context 'with the pinpoint adapter' do
    subject do
      described_class.new(
        to: to,
        otp: otp,
        expiration: expiration,
        channel: channel,
        domain: domain,
        country_code: country_code,
      )
    end

    let(:to) { '+1 (202) 262-1234' }
    let(:otp) { '123456' }
    let(:expiration) { 5 }
    let(:domain) { 'login.gov' }
    let(:country_code) { 'US' }

    before do
      allow(Telephony.config).to receive(:adapter).and_return(:pinpoint)
    end

    context 'for SMS' do
      let(:channel) { :sms }

      it 'sends an authentication OTP with Pinpoint SMS' do
        message = "Login.gov: Your security code is 123456. "\
                  "It expires in 5 minutes. Don't share this "\
                  "code with anyone.\n\n@login.gov #123456"

        adapter = instance_double(Telephony::Pinpoint::SmsSender)
        expect(adapter).to receive(:send).with(
          message: message,
          to: to,
          otp: otp,
          country_code: 'US',
        )
        expect(Telephony::Pinpoint::SmsSender).to receive(:new).and_return(adapter)

        subject.send_authentication_otp
      end

      it 'sends a confirmation OTP with Pinpoint SMS' do
        message = "Login.gov: Your security code is 123456. It "\
        "expires in 5 minutes. Don't share this code with anyone."\
        "\n\n@login.gov #123456"

        adapter = instance_double(Telephony::Pinpoint::SmsSender)
        expect(adapter).to receive(:send).with(
          message: message,
          to: to,
          otp: otp,
          country_code: 'US',
        )
        expect(Telephony::Pinpoint::SmsSender).to receive(:new).and_return(adapter)

        subject.send_confirmation_otp
      end
    end

    context 'for voice' do
      let(:channel) { :voice }

      it 'sends an authentication OTP with Pinpoint Voice' do
        message = <<~XML.squish
          <speak>
            <prosody rate='slow'>
              Hello! Your #{APP_NAME} one time passcode is,
              1 <break time='0.5s' /> 2 <break time='0.5s' /> 3 <break time='0.5s' />
              4 <break time='0.5s' /> 5 <break time='0.5s' /> 6,
              again, your passcode is,
              1 <break time='0.5s' /> 2 <break time='0.5s' /> 3 <break time='0.5s' />
              4 <break time='0.5s' /> 5 <break time='0.5s' /> 6,
              This code expires in 5 minutes.
            </prosody>
          </speak>
        XML

        adapter = instance_double(Telephony::Pinpoint::VoiceSender)
        expect(adapter).to receive(:send).with(
          message: message,
          to: to,
          otp: otp,
          country_code: country_code,
        )
        expect(Telephony::Pinpoint::VoiceSender).to receive(:new).and_return(adapter)

        subject.send_confirmation_otp
      end

      it 'sends a confirmation OTP with Pinpoint Voice' do
        message = <<~XML.squish
          <speak>
            <prosody rate='slow'>
              Hello! Your #{APP_NAME} one time passcode is,
              1 <break time='0.5s' /> 2 <break time='0.5s' /> 3 <break time='0.5s' />
              4 <break time='0.5s' /> 5 <break time='0.5s' /> 6,
              again, your passcode is,
              1 <break time='0.5s' /> 2 <break time='0.5s' /> 3 <break time='0.5s' />
              4 <break time='0.5s' /> 5 <break time='0.5s' /> 6,
              This code expires in 5 minutes.
            </prosody>
          </speak>
        XML

        adapter = instance_double(Telephony::Pinpoint::VoiceSender)
        expect(adapter).to receive(:send).with(
          message: message,
          to: to,
          otp: otp,
          country_code: country_code,
        )
        expect(Telephony::Pinpoint::VoiceSender).to receive(:new).and_return(adapter)

        subject.send_confirmation_otp
      end

      it 'sends valid XML' do
        adapter = instance_double(Telephony::Pinpoint::VoiceSender)
        expect(adapter).to receive(:send) do |args|
          message = args[:message]
          expect { Nokogiri::XML(message) { |config| config.strict } }.to_not raise_error

          {}
        end
        expect(Telephony::Pinpoint::VoiceSender).to receive(:new).and_return(adapter)

        subject.send_confirmation_otp
      end
    end
  end

  describe '#otp_transformed_for_channel' do
    let(:country_code) { 'US' }
    let(:otp_sender) do
      Telephony::OtpSender.new(
        to: '+18888675309',
        otp: otp,
        channel: channel,
        expiration: Time.zone.now,
        domain: 'login.gov',
        country_code: country_code,
      )
    end

    subject(:otp_transformed_for_channel) { otp_sender.send(:otp_transformed_for_channel) }

    context 'for voice' do
      let(:channel) { :voice }

      context 'with a numeric code' do
        let(:otp) { '123456' }

        it 'is the code separated by commas' do
          expect(otp_transformed_for_channel).
            to eq(
              "1 <break time='0.5s' /> 2 <break time='0.5s' /> 3 <break time='0.5s' /> 4 "\
                  "<break time='0.5s' /> 5 <break time='0.5s' /> 6",
            )
        end
      end

      context 'with an alphanumeric code' do
        let(:otp) { 'ABC123' }

        it 'is the code separated by commas' do
          expect(otp_transformed_for_channel).
            to eq(
              "A <break time='0.5s' /> B <break time='0.5s' /> C <break time='0.5s' /> 1 "\
                  "<break time='0.5s' /> 2 <break time='0.5s' /> 3",
            )
        end
      end
    end

    context 'for sms' do
      let(:channel) { :sms }

      let(:otp) { 'ABC123' }

      it 'is the code' do
        expect(otp_transformed_for_channel).to eq(otp)
      end
    end
  end
end
