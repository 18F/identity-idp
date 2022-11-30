require 'nokogiri'
require 'rails_helper'

RSpec.describe Telephony::OtpSender do
  before do
    Telephony::Test::Message.clear_messages
    Telephony::Test::Call.clear_calls
  end

  shared_examples 'pinpoint valid SSML message' do
    it 'does not contain reserved SSML characters' do
      # See: https://docs.aws.amazon.com/polly/latest/dg/escapees.html
      expect(Nokogiri::XML(message) { |config| config.strict }.text).not_to match(/["&'<>]/)
    end
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
        extra_metadata: { phone_fingerprint: 'abc123' },
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

        subject.send_authentication_otp
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
        extra_metadata: {},
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
        message = t(
          'telephony.authentication_otp.sms',
          app_name: APP_NAME,
          code: otp,
          expiration: expiration,
          domain: domain,
        )

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
        message = t(
          'telephony.confirmation_otp.sms',
          app_name: APP_NAME,
          code: otp,
          expiration: expiration,
          domain: domain,
        )

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
              Hello! Your #{APP_NAME} one-time code is,
              1 <break time='0.5s' /> 2 <break time='0.5s' /> 3 <break time='0.5s' />
              4 <break time='0.5s' /> 5 <break time='0.5s' /> 6.
        XML

        adapter = instance_double(Telephony::Pinpoint::VoiceSender)
        expect(adapter).to receive(:send).with(
          message: start_with(message),
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
              Hello! Your #{APP_NAME} one-time code is,
              1 <break time='0.5s' /> 2 <break time='0.5s' /> 3 <break time='0.5s' />
              4 <break time='0.5s' /> 5 <break time='0.5s' /> 6.
        XML

        adapter = instance_double(Telephony::Pinpoint::VoiceSender)
        expect(adapter).to receive(:send).with(
          message: start_with(message),
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
        extra_metadata: {},
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

  describe '#authentication_message' do
    let(:channel) { nil }
    let(:sender) do
      Telephony::OtpSender.new(
        to: '+18888675309',
        otp: 'ABC123',
        channel: channel,
        expiration: TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_MINUTES,
        domain: 'secure.login.gov',
        country_code: 'US',
        extra_metadata: {},
      )
    end

    subject(:message) { sender.authentication_message }

    context 'sms' do
      let(:channel) { :sms }

      context 'English' do
        it 'does not contain any non-GSM characters and is less than or equal to 160 characters' do
          expect(Telephony.sms_parts(message)).to eq 1
          expect(Telephony.gsm_chars_only?(message)).to eq true
        end
      end

      # The Spanish-language translation currently includes the 'ó', character, which is not
      # in the GSM 03.38 character set
      context 'Spanish' do
        it 'is sent in three parts' do
          I18n.locale = :es

          expect(Telephony.sms_parts(message)).to eq 3
        ensure
          I18n.locale = :en
        end
      end

      context 'French' do
        it 'does not contain any non-GSM characters and is less than or equal to 160 characters' do
          I18n.locale = :fr

          expect(Telephony.sms_parts(message)).to eq 1
          expect(Telephony.gsm_chars_only?(message)).to eq true
        ensure
          I18n.locale = :en
        end
      end
    end

    context 'voice' do
      let(:channel) { :voice }
      let(:locale) { nil }

      before { I18n.locale = locale }

      context 'English' do
        let(:locale) { :en }

        it_behaves_like 'pinpoint valid SSML message'
      end

      context 'Spanish' do
        let(:locale) { :es }

        it_behaves_like 'pinpoint valid SSML message'
      end

      context 'French' do
        let(:locale) { :fr }

        it_behaves_like 'pinpoint valid SSML message'
      end
    end
  end

  describe '#confirmation_message' do
    let(:channel) { nil }
    let(:sender) do
      Telephony::OtpSender.new(
        to: '+18888675309',
        otp: 'ABC123',
        channel: channel,
        expiration: TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_MINUTES,
        domain: 'secure.login.gov',
        country_code: 'US',
        extra_metadata: {},
      )
    end

    subject(:message) { sender.confirmation_message }

    context 'sms' do
      let(:channel) { :sms }

      context 'English' do
        it 'does not contain any non-GSM characters and is sent in one part' do
          expect(Telephony.sms_parts(message)).to eq 1
          expect(Telephony.gsm_chars_only?(message)).to eq true
        end
      end

      # The Spanish-language translation currently includes the 'ó', character, which is not
      # in the GSM 03.38 character set
      context 'Spanish' do
        it 'is sent in three parts' do
          I18n.locale = :es

          expect(Telephony.sms_parts(message)).to eq 3
        ensure
          I18n.locale = :en
        end
      end

      context 'French' do
        it 'does not contain any non-GSM characters and is sent in one part' do
          I18n.locale = :fr

          expect(Telephony.sms_parts(message)).to eq 1
          expect(Telephony.gsm_chars_only?(message)).to eq true
        ensure
          I18n.locale = :en
        end
      end
    end

    context 'voice' do
      let(:channel) { :voice }
      let(:locale) { nil }

      before { I18n.locale = locale }

      context 'English' do
        let(:locale) { :en }

        it_behaves_like 'pinpoint valid SSML message'
      end

      context 'Spanish' do
        let(:locale) { :es }

        it_behaves_like 'pinpoint valid SSML message'
      end

      context 'French' do
        let(:locale) { :fr }

        it_behaves_like 'pinpoint valid SSML message'
      end
    end
  end
end
