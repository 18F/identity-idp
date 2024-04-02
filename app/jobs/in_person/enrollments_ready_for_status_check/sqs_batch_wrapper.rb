# frozen_string_literal: true

module InPerson::EnrollmentsReadyForStatusCheck
  class SqsBatchWrapper
    # @param [Aws::SQS::Client] sqs_client AWS SQS Client
    # @param [String] queue_url The URL identifying the SQS queue
    # @param [Hash] receive_params Parameters passed to #receive_message
    def initialize(sqs_client:, queue_url:, receive_params:)
      @sqs_client = sqs_client
      @queue_url = queue_url
      @receive_params = receive_params
    end

    # Fetch a batch of messages from the SQS queue
    # @return [Array<Aws::SQS::Types::Message>]
    def poll
      sqs_client.receive_message(receive_params).messages
    end

    # Delete the provided messages from the SQS queue
    # @param [Array<Aws::SQS::Types::Message>] batch
    # @return [Aws::SQS::Types::DeleteMessageBatchResult]
    def delete_message_batch(batch)
      sqs_client.delete_message_batch(
        queue_url:,
        entries: batch.map do |message|
          {
            id: message.message_id,
            receipt_handle: message.receipt_handle,
          }
        end,
      )
    end

    private

    attr_reader :sqs_client, :queue_url, :receive_params
  end
end
