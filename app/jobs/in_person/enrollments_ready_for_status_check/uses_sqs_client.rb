module InPerson::EnrollmentsReadyForStatusCheck
  module UsesSqsClient
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
        {
          queue_url:,
          entries: batch.map do |message|
            {
              id: message.message_id,
              receipt_handle: message.receipt_handle,
            }
          end,
        },
      )
    end

    private

    def sqs_client
      @sqs_client ||= Aws::SQS::Client.new
    end

    def queue_url
      IdentityConfig.store.in_person_enrollments_ready_job_queue_url
    end

    def receive_params
      {
        queue_url:,
        max_number_of_messages:
          IdentityConfig.store.in_person_enrollments_ready_job_max_number_of_messages,
        visibility_timeout: IdentityConfig.store.in_person_enrollments_ready_job_visibility_timeout,
        wait_time_seconds: IdentityConfig.store.in_person_enrollments_ready_job_wait_time_seconds,
      }
    end
  end
end
