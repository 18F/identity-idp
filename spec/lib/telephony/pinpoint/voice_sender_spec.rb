require 'rails_helper'

describe Telephony::Pinpoint::VoiceSender do
  include_context 'telephony'

  subject(:voice_sender) { described_class.new }

  let(:pinpoint_client) { Aws::PinpointSMSVoice::Client.new(stub_responses: true) }
  let(:voice_config) { Telephony.config.pinpoint.voice_configs.first }

  let(:backup_pinpoint_client) { Aws::PinpointSMSVoice::Client.new(stub_responses: true) }
  let(:backup_voice_config) { Telephony.config.pinpoint.voice_configs.last }

  def mock_build_client
    allow(voice_sender).
    to receive(:build_client).with(voice_config).and_return(pinpoint_client)
  end

  def mock_build_backup_client
    allow(voice_sender).
    to receive(:build_client).with(backup_voice_config).and_return(backup_pinpoint_client)
  end

  describe '#send' do
    let(:pinpoint_response) do
      double(message_id: 'fake-message-id')
    end
    let(:message) { '<speak>This is a test!</speak>' }
    let(:sending_phone) { '+12223334444' }
    let(:recipient_phone) { '+1 (123) 456-7890' }
    let(:expected_message) do
      {
        content: {
          ssml_message: {
            text: message,
            language_code: 'en-US',
            voice_id: 'Joey',
          },
        },
        destination_phone_number: recipient_phone,
        origination_phone_number: sending_phone,
      }
    end

    before do
      # More deterministic sending phone
      Telephony.config.pinpoint.voice_configs.first.longcode_pool = [sending_phone]

      mock_build_client
    end

    it 'initializes a pinpoint sms and voice client and uses that to send a message' do
      expect(pinpoint_client).to receive(:send_voice_message).
        with(expected_message).
        and_return(pinpoint_response)

      response = voice_sender.send(message: message, to: recipient_phone, country_code: 'US')

      expect(response.success?).to eq(true)
      expect(response.extra[:message_id]).to eq('fake-message-id')
    end

    context 'when the current locale is spanish' do
      before do
        allow(I18n).to receive(:locale).and_return(:es)
      end

      it 'calls the user with a spanish voice' do
        expected_message[:content][:ssml_message][:language_code] = 'es-US'
        expected_message[:content][:ssml_message][:voice_id] = 'Miguel'
        expect(pinpoint_client).to receive(:send_voice_message).
          with(expected_message).
          and_return(pinpoint_response)

        response = voice_sender.send(message: message, to: recipient_phone, country_code: 'US')

        expect(response.success?).to eq(true)
        expect(response.extra[:message_id]).to eq('fake-message-id')
      end
    end

    context 'when the current locale is french' do
      before do
        allow(I18n).to receive(:locale).and_return(:fr)
      end

      it 'calls the user with a french voice' do
        expected_message[:content][:ssml_message][:language_code] = 'fr-FR'
        expected_message[:content][:ssml_message][:voice_id] = 'Mathieu'
        expect(pinpoint_client).to receive(:send_voice_message).
          with(expected_message).
          and_return(pinpoint_response)

        response = voice_sender.send(message: message, to: recipient_phone, country_code: 'US')

        expect(response.success?).to eq(true)
        expect(response.extra[:message_id]).to eq('fake-message-id')
      end
    end

    context 'when pinpoint responds with a limit exceeded response' do
      it 'returns a telephony error' do
        exception = Aws::PinpointSMSVoice::Errors::LimitExceededException.new(
          Seahorse::Client::RequestContext.new,
          'This is a test message',
        )
        expect(pinpoint_client).to receive(:send_voice_message).and_raise(exception)

        response = voice_sender.send(message: message, to: recipient_phone, country_code: 'US')

        error_message =
          'Aws::PinpointSMSVoice::Errors::LimitExceededException: This is a test message'

        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::ThrottledError.new(error_message))
      end
    end

    context 'when pinpoint responds with a TooManyRequestsException' do
      it 'returns a DailyLimitReachedError' do
        exception = Aws::PinpointSMSVoice::Errors::TooManyRequestsException.new(
          Seahorse::Client::RequestContext.new,
          'This is a test message',
        )
        expect(pinpoint_client).to receive(:send_voice_message).and_raise(exception)

        response = voice_sender.send(message: message, to: recipient_phone, country_code: 'US')

        error_message =
          'Aws::PinpointSMSVoice::Errors::TooManyRequestsException: This is a test message'

        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::DailyLimitReachedError.new(error_message))
        expect(response.error.friendly_message).to eq(
          t('telephony.error.friendly_message.daily_voice_limit_reached'),
        )
      end
    end

    context 'when pinpoint responds with an internal service error' do
      it 'returns a telephony error' do
        exception = Aws::PinpointSMSVoice::Errors::InternalServiceErrorException.new(
          Seahorse::Client::RequestContext.new,
          'This is a test message',
        )
        expect(pinpoint_client).to receive(:send_voice_message).and_raise(exception)

        response = voice_sender.send(message: message, to: recipient_phone, country_code: 'US')

        error_message =
          'Aws::PinpointSMSVoice::Errors::InternalServiceErrorException: This is a test message'

        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::TelephonyError.new(error_message))
      end
    end

    context 'when pinpoint responds with a generic error' do
      it 'returns a telephony error' do
        exception = Aws::PinpointSMSVoice::Errors::BadRequestException.new(
          Seahorse::Client::RequestContext.new,
          'This is a test message',
        )
        expect(pinpoint_client).to receive(:send_voice_message).and_raise(exception)

        response = voice_sender.send(message: message, to: recipient_phone, country_code: 'US')

        error_message =
          'Aws::PinpointSMSVoice::Errors::BadRequestException: This is a test message'

        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::TelephonyError.new(error_message))
      end
    end

    context 'when pinpoint raises a timeout exception' do
      it 'rescues the exception and returns an error' do
        exception = Seahorse::Client::NetworkingError.new(Net::ReadTimeout.new)
        expect(pinpoint_client).
          to receive(:send_voice_message).and_raise(exception)

        response = voice_sender.send(message: message, to: recipient_phone, country_code: 'US')

        error_message = 'Seahorse::Client::NetworkingError: Net::ReadTimeout'

        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::TelephonyError.new(error_message))
      end
    end

    context 'with multiple voice configs' do
      before do
        Telephony.config.pinpoint.add_voice_config do |voice|
          voice.region = 'backup-region'
          voice.access_key_id = 'fake-pinpoint-access-key-id-voice'
          voice.secret_access_key = 'fake-pinpoint-secret-access-key-voice'
          voice.longcode_pool = [backup_longcode]
        end

        mock_build_backup_client
      end

      let(:backup_longcode) { '+18881112222' }

      context 'when the first config succeeds' do
        before do
          expect(pinpoint_client).to receive(:send_voice_message).
            with(expected_message).
            and_return(pinpoint_response)

          expect(backup_pinpoint_client).to_not receive(:send_voice_message)
        end

        it 'only tries one client' do
          response = voice_sender.send(message: message, to: recipient_phone, country_code: 'US')
          expect(response.success?).to eq(true)
          expect(response.extra[:message_id]).to eq('fake-message-id')
        end
      end

      context 'when the first config errors' do
        before do
          # first config errors
          exception = Aws::PinpointSMSVoice::Errors::BadRequestException.new(
            Seahorse::Client::RequestContext.new,
            'This is a test message',
          )
          expect(pinpoint_client).to receive(:send_voice_message).and_raise(exception)

          # second config succeeds
          expected_message[:origination_phone_number] = backup_longcode
          expect(backup_pinpoint_client).to receive(:send_voice_message).
            with(expected_message).
            and_return(pinpoint_response)
        end

        it 'logs a warning and tries the other configs' do
          expect(Telephony.config.logger).to receive(:warn)

          response = voice_sender.send(message: message, to: recipient_phone, country_code: 'US')
          expect(response.success?).to eq(true)
          expect(response.extra[:message_id]).to eq('fake-message-id')
        end
      end
    end

    context 'when all voice configs fail to build' do
      let(:raised_error_message) { 'Failed to load AWS config' }
      let(:pinpoint_client) { nil }
      let(:backup_pinpoint_client) { nil }

      it 'logs a warning and returns an error' do
        expect(Telephony.config.logger).to receive(:warn)

        response = subject.send(
          message: 'This is a test!',
          to: '+1 (123) 456-7890',
          country_code: 'US',
        )
        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::UnknownFailureError.new(raised_error_message))
      end
    end
  end
end
