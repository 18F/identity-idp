require 'rails_helper'

describe Telephony::Pinpoint::SmsSender do
  include_context 'telephony'

  subject(:sms_sender) { described_class.new }
  let(:sms_config) { Telephony.config.pinpoint.sms_configs.first }
  let(:backup_sms_config) { Telephony.config.pinpoint.sms_configs.last }
  let(:backup_mock_client) { Pinpoint::MockClient.new(backup_sms_config) }
  let(:mock_client) { Pinpoint::MockClient.new(sms_config) }

  # Monkeypatch library class so we can use it for argument matching
  class Aws::Credentials
    def ==(other)
      self.access_key_id == other.access_key_id &&
        self.secret_access_key == other.secret_access_key
    end
  end

  describe 'error handling' do
    let(:status_code) { 400 }
    let(:delivery_status) { 'DUPLICATE' }
    let(:raised_error_message) { "Pinpoint Error: #{delivery_status} - #{status_code}" }
    let(:status_message) { 'some status message' }

    before do
      mock_build_client

      Pinpoint::MockClient.message_response_result_status_code = status_code
      Pinpoint::MockClient.message_response_result_delivery_status = delivery_status
      Pinpoint::MockClient.message_response_result_status_message = status_message
    end

    context 'when endpoint is a duplicate' do
      let(:delivery_status) { 'DUPLICATE' }

      it 'raises a duplicate endpoint error' do
        response = subject.send(message: 'hello!', to: '+11234567890', country_code: 'US')

        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::DuplicateEndpointError.new(raised_error_message))
        expect(response.extra[:delivery_status]).to eq('DUPLICATE')
        expect(response.extra[:request_id]).to eq('fake-message-request-id')
      end
    end

    context 'when the user opts out' do
      let(:delivery_status) { 'OPT_OUT' }

      it 'raises an opt out error' do
        response = subject.send(message: 'hello!', to: '+11234567890', country_code: 'US')

        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::OptOutError.new(raised_error_message))
        expect(response.extra[:delivery_status]).to eq('OPT_OUT')
        expect(response.extra[:request_id]).to eq('fake-message-request-id')
      end
    end

    context 'when a permanent failure occurs' do
      let(:delivery_status) { 'PERMANENT_FAILURE' }

      it 'raises a permanent failure error' do
        response = subject.send(message: 'hello!', to: '+11234567890', country_code: 'US')

        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::PermanentFailureError.new(raised_error_message))
        expect(response.extra[:delivery_status]).to eq('PERMANENT_FAILURE')
        expect(response.extra[:request_id]).to eq('fake-message-request-id')
      end

      context 'when the message indicates opt out' do
        let(:status_message) { '+11234567890 is opted out' }

        it 'raises an OptOutError instead' do
          response = subject.send(message: 'hello!', to: '+11234567890', country_code: 'US')

          expect(response.success?).to eq(false)
          expect(response.error).to eq(Telephony::OptOutError.new(raised_error_message))
        end
      end
    end

    context 'when a temporary failure occurs' do
      let(:delivery_status) { 'TEMPORARY_FAILURE' }

      it 'raises an opt out error' do
        response = subject.send(message: 'hello!', to: '+11234567890', country_code: 'US')

        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::TemporaryFailureError.new(raised_error_message))
        expect(response.extra[:delivery_status]).to eq('TEMPORARY_FAILURE')
        expect(response.extra[:request_id]).to eq('fake-message-request-id')
      end
    end

    context 'when the request is throttled' do
      let(:delivery_status) { 'THROTTLED' }

      it 'raises an opt out error' do
        response = subject.send(message: 'hello!', to: '+11234567890', country_code: 'US')

        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::ThrottledError.new(raised_error_message))
        expect(response.extra[:delivery_status]).to eq('THROTTLED')
        expect(response.extra[:request_id]).to eq('fake-message-request-id')
      end
    end

    context 'when the request times out' do
      let(:delivery_status) { 'TIMEOUT' }

      it 'raises an opt out error' do
        response = subject.send(message: 'hello!', to: '+11234567890', country_code: 'US')

        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::TimeoutError.new(raised_error_message))
        expect(response.extra[:delivery_status]).to eq('TIMEOUT')
        expect(response.extra[:request_id]).to eq('fake-message-request-id')
      end
    end

    context 'when an unkown error occurs' do
      let(:delivery_status) { 'UNKNOWN_FAILURE' }

      it 'raises an opt out error' do
        response = subject.send(message: 'hello!', to: '+11234567890', country_code: 'US')

        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::UnknownFailureError.new(raised_error_message))
        expect(response.extra[:delivery_status]).to eq('UNKNOWN_FAILURE')
        expect(response.extra[:request_id]).to eq('fake-message-request-id')
      end
    end

    context 'when the API responds with an unrecognized error' do
      let(:delivery_status) { '' }

      it 'raises a generic telephony error' do
        response = subject.send(message: 'hello!', to: '+11234567890', country_code: 'US')

        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::TelephonyError.new(raised_error_message))
        expect(response.extra[:delivery_status]).to eq('')
        expect(response.extra[:request_id]).to eq('fake-message-request-id')
      end
    end

    context 'when a timeout exception is raised' do
      let(:raised_error_message) { 'Seahorse::Client::NetworkingError: Net::ReadTimeout' }

      it 'handles the exception' do
        expect(mock_client).to receive(:send_messages).and_raise(
          Seahorse::Client::NetworkingError.new(Net::ReadTimeout.new),
        )
        response = subject.send(message: 'hello!', to: '+11234567890', country_code: 'US')
        expect(response.success?).to eq(false)
        expect(response.error).to eq(Telephony::TelephonyError.new(raised_error_message))
        expect(response.extra[:delivery_status]).to eq nil
        expect(response.extra[:request_id]).to eq nil
      end
    end
  end

  describe '#send' do
    let(:country_code) { 'US' }

    before do
      Telephony.config.country_sender_ids = {
        PH: 'sender2',
      }
    end

    context 'in a country with sender_id' do
      let(:country_code) { 'PH' }

      it 'sends a message with a sender_id and no origination number' do
        mock_build_client
        response = subject.send(
          message: 'This is a test!',
          to: '+1 (604) 456-7890',
          country_code: country_code,
        )

        expected_result = {
          application_id: Telephony.config.pinpoint.sms_configs.first.application_id,
          message_request: {
            addresses: {
              '+1 (604) 456-7890' => { channel_type: 'SMS' },
            },
            message_configuration: {
              sms_message: {
                body: 'This is a test!',
                message_type: 'TRANSACTIONAL',
                sender_id: 'sender2',
              },
            },
          },
        }

        expect(Pinpoint::MockClient.last_request).to eq(expected_result)
        expect(response.success?).to eq(true)
        expect(response.error).to eq(nil)
        expect(response.extra[:request_id]).to eq('fake-message-request-id')
      end
    end

    context 'in the US' do
      it 'sends a message with a shortcode and no sender_id' do
        mock_build_client
        response = subject.send(
          message: 'This is a test!',
          to: '+1 (414) 456-7890',
          country_code: country_code,
        )

        expected_result = {
          application_id: Telephony.config.pinpoint.sms_configs.first.application_id,
          message_request: {
            addresses: {
              '+1 (414) 456-7890' => { channel_type: 'SMS' },
            },
            message_configuration: {
              sms_message: {
                body: 'This is a test!',
                message_type: 'TRANSACTIONAL',
                origination_number: '123456',
              },
            },
          },
        }

        expect(Pinpoint::MockClient.last_request).to eq(expected_result)
        expect(response.success?).to eq(true)
        expect(response.error).to eq(nil)
        expect(response.extra[:request_id]).to eq('fake-message-request-id')
      end
    end

    context 'in a non-sender_id country that has a configured long code pool' do
      let(:country_code) { 'PR' }

      it 'sends a message with a longcode and no sender_id' do
        mock_build_client
        response = subject.send(
          message: 'This is a test!',
          to: '+1 (939) 456-7890',
          country_code: country_code,
        )

        expected_result = {
          application_id: Telephony.config.pinpoint.sms_configs.first.application_id,
          message_request: {
            addresses: {
              '+1 (939) 456-7890' => { channel_type: 'SMS' },
            },
            message_configuration: {
              sms_message: {
                body: 'This is a test!',
                message_type: 'TRANSACTIONAL',
                origination_number: '+19393334444',
              },
            },
          },
        }

        expect(Pinpoint::MockClient.last_request).to eq(expected_result)
        expect(response.success?).to eq(true)
        expect(response.error).to eq(nil)
        expect(response.extra[:request_id]).to eq('fake-message-request-id')
      end
    end

    context 'with multiple sms configs' do
      before do
        Telephony.config.pinpoint.add_sms_config do |sms|
          sms.region = 'backup-sms-region'
          sms.access_key_id = 'fake-pnpoint-access-key-id-sms'
          sms.secret_access_key = 'fake-pinpoint-secret-access-key-sms'
          sms.application_id = 'backup-sms-application-id'
        end

        mock_build_client
        mock_build_backup_client
      end

      context 'when the first config succeeds' do
        it 'only tries one client' do
          expect(backup_mock_client).to_not receive(:send_messages)

          response = subject.send(
            message: 'This is a test!',
            to: '+1 (123) 456-7890',
            country_code: 'US',
          )
          expect(response.success?).to eq(true)
        end
      end

      context 'when the first config errors with a transient error' do
        before do
          Pinpoint::MockClient.message_response_result_status_code = 400
          Pinpoint::MockClient.message_response_result_delivery_status = 'DUPLICATE'
        end

        it 'logs a warning for each failure and tries the other configs' do
          expect(Telephony.config.logger).to receive(:warn).exactly(2).times

          response = subject.send(
            message: 'This is a test!',
            to: '+1 (123) 456-7890',
            country_code: 'US',
          )

          expect(response.success?).to eq(false)
        end
      end

      context 'when the first config errors with an opt out error' do
        before do
          Pinpoint::MockClient.message_response_result_status_code = 400
          Pinpoint::MockClient.message_response_result_delivery_status = 'OPT_OUT'
        end

        it 'only tries one region and returns an error' do
          expect(backup_mock_client).to_not receive(:send_messages)

          response = subject.send(
            message: 'This is a test!',
            to: '+1 (123) 456-7890',
            country_code: 'US',
          )
          expect(response.success?).to eq(false)
          expect(response.error).to be_present
        end
      end

      context 'when the first config errors with a permanent error' do
        before do
          Pinpoint::MockClient.message_response_result_status_code = 400
          Pinpoint::MockClient.message_response_result_delivery_status = 'PERMANENT_FAILURE'
        end

        it 'only tries one region and returns an error' do
          expect(backup_mock_client).to_not receive(:send_messages)

          response = subject.send(
            message: 'This is a test!',
            to: '+1 (123) 456-7890',
            country_code: 'US',
          )
          expect(response.success?).to eq(false)
          expect(response.error).to be_present
        end
      end

      context 'when the first config raises a timeout exception' do
        let(:raised_error_message) { 'Seahorse::Client::NetworkingError: Net::ReadTimeout' }

        it 'logs a warning for each failure and tries the other configs' do
          expect(mock_client).to receive(:send_messages).and_raise(
            Seahorse::Client::NetworkingError.new(
              Net::ReadTimeout.new,
            ),
          ).once
          expect(backup_mock_client).to receive(:send_messages).and_raise(
            Seahorse::Client::NetworkingError.new(
              Net::ReadTimeout.new,
            ),
          ).once

          response = subject.send(
            message: 'This is a test!',
            to: '+1 (123) 456-7890',
            country_code: 'US',
          )
          expect(response.success?).to eq(false)
          expect(response.error).to eq(Telephony::TelephonyError.new(raised_error_message))
        end
      end

      context 'when all sms configs fail to build' do
        let(:raised_error_message) { 'Failed to load AWS config' }
        let(:mock_client) { nil }
        let(:backup_mock_client) { nil }

        it 'logs a warning and returns an error' do
          expect(Telephony.config.logger).to receive(:warn).once

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

    context 'when the exception message contains a phone number' do
      let(:phone_numbers) do
        Aws::Pinpoint::Types::SendMessagesResponse.new(
          message_response: Aws::Pinpoint::Types::MessageResponse.new(
            result: { phone: Aws::Pinpoint::Types::MessageResult.new(
              delivery_status: 'PERMANENT_FAILURE',
              message_id: 'abc',
              status_code: 400,
              status_message: '+1-555-5555 +15555555 (555)-5555',
              updated_token: '',
            ) },
          ),
        )
      end

      before do
        mock_build_client
        mock_build_backup_client

        allow(mock_client).to receive(:send_messages).and_return(phone_numbers)
        allow(backup_mock_client).to receive(:send_messages).and_return(phone_numbers)
      end

      it 'does not include the phone number in the results' do
        response = subject.send(
          message: 'This is a test!',
          to: '+1 (123) 456-7890',
          country_code: 'US',
        )
        expect(response.extra[:status_message]).to_not match(/\d/)
        expect(response.extra[:status_message]).to include('+x-xxx-xxxx +xxxxxxxx (xxx)-xxxx')
      end
    end
  end

  def mock_build_client(client = mock_client)
    expect(sms_sender).to receive(:build_client).with(sms_config).and_return(client)
  end

  def mock_build_backup_client(client = backup_mock_client)
    allow(sms_sender).to receive(:build_client).with(backup_sms_config).and_return(client)
  end

  describe '#phone_info' do
    let(:phone_number) { '+18888675309' }
    let(:pinpoint_client) { Aws::Pinpoint::Client.new(stub_responses: true) }

    subject(:phone_info) do
      sms_sender.phone_info(phone_number)
    end

    before do
      Telephony.config.pinpoint.add_sms_config do |sms|
        sms.region = 'backup-sms-region'
        sms.access_key_id = 'fake-pnpoint-access-key-id-sms'
        sms.secret_access_key = 'fake-pinpoint-secret-access-key-sms'
        sms.application_id = 'backup-sms-application-id'
      end

      mock_build_client(pinpoint_client)
      mock_build_backup_client(pinpoint_client)
    end

    context 'successful network requests' do
      before do
        pinpoint_client.stub_responses(
          :phone_number_validate,
          number_validate_response: {
            phone_type: phone_type,
            carrier: 'Example Carrier',
          },
        )
      end

      let(:phone_type) { 'MOBILE' }

      it 'has the carrier' do
        expect(phone_info.carrier).to eq('Example Carrier')
      end

      it 'has a blank error' do
        expect(phone_info.error).to be_nil
      end

      context 'when the phone number is a mobile number' do
        let(:phone_type) { 'MOBILE' }
        it { expect(phone_info.type).to eq(:mobile) }
      end

      context 'when the phone number is a voip number' do
        let(:phone_type) { 'VOIP' }
        it { expect(phone_info.type).to eq(:voip) }
      end

      context 'when the phone number is a landline number' do
        let(:phone_type) { 'LANDLINE' }
        it { expect(phone_info.type).to eq(:landline) }
      end

      context 'when the phone number is some unhandled type' do
        let(:phone_type) { 'NEW_MAGICAL_TYPE' }
        it { expect(phone_info.type).to eq(:unknown) }
      end
    end

    context 'when the first config raises a timeout exception' do
      let(:phone_type) { 'VOIP' }

      before do
        pinpoint_client.stub_responses(
          :phone_number_validate, [
            Seahorse::Client::NetworkingError.new(Timeout::Error.new),
            { number_validate_response: { phone_type: phone_type } },
          ]
        )
      end

      it 'logs a warning for each failure and tries the other configs' do
        expect(Telephony.config.logger).to receive(:warn).exactly(1).times

        expect(phone_info.type).to eq(:voip)
        expect(phone_info.error).to be_nil
      end
    end

    context 'when all configs raise errors' do
      before do
        pinpoint_client.stub_responses(
          :phone_number_validate,
          Seahorse::Client::NetworkingError.new(Timeout::Error.new),
        )
      end

      it 'logs a warning for each failure and returns unknown' do
        expect(Telephony.config.logger).to receive(:warn).exactly(2).times

        expect(phone_info.type).to eq(:unknown)
        expect(phone_info.error).to be_kind_of(Seahorse::Client::NetworkingError)
      end
    end

    context 'when all sms configs fail to build' do
      let(:pinpoint_client) { nil }

      it 'returns unknown' do
        expect(phone_info.type).to eq(:unknown)
        expect(phone_info.error).to be_kind_of(Telephony::UnknownFailureError)
      end
    end
  end
end
