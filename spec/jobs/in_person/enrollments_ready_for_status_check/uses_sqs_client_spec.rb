require 'rails_helper'

RSpec.describe InPerson::EnrollmentsReadyForStatusCheck::UsesSqsClient do
  let(:queue_url) { 'my/test/queue/url' }
  subject(:uses_sqs_client) { Class.new.include(described_class).new }

  context 'with SQS client' do
    let(:sqs_client) { instance_double(Aws::SQS::Client) }

    def create_mock_message
      instance_double(Aws::SQS::Types::Message)
    end

    before(:each) do
      allow(Aws::SQS::Client).to receive(:new).and_return(sqs_client)
      allow(IdentityConfig.store).to receive(:in_person_enrollments_ready_job_queue_url).
        and_return(queue_url)
    end

    describe '#poll' do
      it 'polls SQS and returns messages' do
        mock_result = instance_double(Aws::SQS::Types::ReceiveMessageResult)
        mock_messages = [
          create_mock_message,
          create_mock_message,
          create_mock_message,
        ]
        max_number_of_messages = 10
        visibility_timeout = 30
        wait_time_seconds = 20

        allow(IdentityConfig.store).to receive(
          :in_person_enrollments_ready_job_max_number_of_messages,
        ).and_return(max_number_of_messages)
        allow(IdentityConfig.store).to receive(
          :in_person_enrollments_ready_job_visibility_timeout,
        ).and_return(visibility_timeout)
        allow(IdentityConfig.store).to receive(
          :in_person_enrollments_ready_job_wait_time_seconds,
        ).and_return(wait_time_seconds)

        expect(sqs_client).to receive(:receive_message).with(
          {
            queue_url:,
            max_number_of_messages:,
            visibility_timeout:,
            wait_time_seconds:,
          },
        ).and_return(mock_result)

        expect(mock_result).to receive(:messages).and_return(mock_messages)
        expect(uses_sqs_client.poll).to eq(mock_messages)
      end
    end

    describe '#delete_message_batch' do
      it 'deletes a batch of 1 from SQS' do
        message_id = Random.uuid
        receipt_handle = Random.uuid
        message = create_mock_message
        allow(message).to receive(:message_id).and_return(message_id)
        allow(message).to receive(:receipt_handle).and_return(receipt_handle)
        deletion_result = instance_double(Aws::SQS::Types::DeleteMessageBatchResult)
        expect(sqs_client).to receive(:delete_message_batch).with(
          {
            queue_url:,
            entries: [
              {
                id: message_id,
                receipt_handle: receipt_handle,
              },
            ],
          },
        ).and_return(deletion_result)
        expect(uses_sqs_client.delete_message_batch([message])).to be(deletion_result)
      end
      it 'deletes a batch of 2 from SQS' do
        message_id = Random.uuid
        receipt_handle = Random.uuid
        message = create_mock_message
        allow(message).to receive(:message_id).and_return(message_id)
        allow(message).to receive(:receipt_handle).and_return(receipt_handle)

        message_id2 = Random.uuid
        receipt_handle2 = Random.uuid
        message2 = create_mock_message
        allow(message2).to receive(:message_id).and_return(message_id2)
        allow(message2).to receive(:receipt_handle).and_return(receipt_handle2)

        deletion_result = instance_double(Aws::SQS::Types::DeleteMessageBatchResult)
        expect(sqs_client).to receive(:delete_message_batch).with(
          {
            queue_url:,
            entries: [
              {
                id: message_id,
                receipt_handle: receipt_handle,
              },
              {
                id: message_id2,
                receipt_handle: receipt_handle2,
              },
            ],
          },
        ).and_return(deletion_result)
        expect(uses_sqs_client.delete_message_batch([message, message2])).to be(deletion_result)
      end
    end
  end
end
