module InPerson::EnrollmentsReadyForStatusCheck
  module BatchProcessor
    include UsesReportError
    include UsesSqsClient
    include EnrollmentPipeline

    def process_batch(messages, analytics_stats)
      analytics_stats[:fetched_items] += messages.size
      # Keep messages to delete in an array for a batch call
      deletion_batch = []
      messages.each do |sqs_message|
        if process_message(sqs_message)
          analytics_stats[:valid_items] += 1
        else
          analytics_stats[:invalid_items] += 1
        end

        # Append messages to batch so we can dequeue any that we've processed.
        #
        # If we fail to process the message now but could process it later, then
        # we should exclude that message from the deletion batch.
        deletion_batch.append(sqs_message)
        analytics_stats[:processed_items] += 1
      end
    ensure
      begin
        # The messages were processed, so remove them from the queue
        unless deletion_batch.empty?
          delete_result = delete_message_batch(deletion_batch)
          delete_result.failed.each do |error_entry|
            report_error(
              'Failed to delete item from queue',
              sqs_delete_error: error_entry.to_h,
            )
          end
          analytics_stats[:deleted_items] += delete_result.successful.size
        end
      rescue StandardError => err
        report_error(err)
      end
    end
  end
end
