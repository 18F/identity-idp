require 'rails_helper'

RSpec.describe InPerson::EnrollmentsReadyForStatusCheck::SqsBatchWrapper do
  let(:queue_url) { 'my/test/queue/url' }
  let(:sqs_client) { instance_double(Aws::SQS::Client) }
  let(:receive_params) do
    {
      queue_url:,
      max_number_of_messages: 10,
      visibility_timeout: 30,
      wait_time_seconds: 20,
    }
  end
  subject(:sqs_batch_wrapper) { described_class.new(sqs_client:, queue_url:, receive_params:) }

  def create_mock_message
    instance_double(Aws::SQS::Types::Message)
  end

  describe '#poll' do
    it 'polls SQS and returns messages' do
      mock_result = instance_double(Aws::SQS::Types::ReceiveMessageResult)
      mock_messages = [
        create_mock_message,
        create_mock_message,
        create_mock_message,
      ]

      expect(sqs_client).to receive(:receive_message).
        with(receive_params).
        and_return(mock_result)

      expect(mock_result).to receive(:messages).and_return(mock_messages)
      expect(sqs_batch_wrapper.poll).to eq(mock_messages)
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
              receipt_handle:,
            },
          ],
        },
      ).and_return(deletion_result)
      expect(sqs_batch_wrapper.delete_message_batch([message])).to be(deletion_result)
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
              receipt_handle:,
            },
            {
              id: message_id2,
              receipt_handle: receipt_handle2,
            },
          ],
        },
      ).and_return(deletion_result)
      expect(sqs_batch_wrapper.delete_message_batch([message, message2])).to be(deletion_result)
    end
  end
end
