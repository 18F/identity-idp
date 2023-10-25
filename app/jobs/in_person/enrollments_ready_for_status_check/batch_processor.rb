# frozen_string_literal: true

module InPerson::EnrollmentsReadyForStatusCheck
  class BatchProcessor
    # @param [InPerson::EnrollmentsReadyForStatusCheck::ErrorReporter] error_reporter
    # @param [InPerson::EnrollmentsReadyForStatusCheck::SqsBatchWrapper] sqs_batch_wrapper
    # @param [InPerson::EnrollmentsReadyForStatusCheck::EnrollmentPipeline] enrollment_pipeline
    def initialize(error_reporter:, sqs_batch_wrapper:, enrollment_pipeline:)
      @error_reporter = error_reporter
      @sqs_batch_wrapper = sqs_batch_wrapper
      @enrollment_pipeline = enrollment_pipeline
    end

    # Process a batch of incoming messages corresponding to in-person
    # enrollments that are ready to have their status checked.
    #
    # Note: Stats are accepted as param to increment and facilitate logging even
    # if this method raises an error.
    #
    # @param [Array<Aws::SQS::Types::Message>] messages In-person enrollment SQS messages
    # @param [Hash] analytics_stats Counters for aggregating info about how items were processed
    # @option analytics_stats [Integer] :fetched_items Items received from SQS
    # @option analytics_stats [Integer] :valid_items Items matching the expected format/data
    # @option analytics_stats [Integer] :invalid_items Items not matching the expected format/data
    # @option analytics_stats [Integer] :processed_items Items processed without errors
    # @option analytics_stats [Integer] :deleted_items Items successfully deleted from queue
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
      # The messages were processed, so remove them from the queue
      analytics_stats[:deleted_items] += process_deletions(deletion_batch)
    end

    private

    attr_reader :error_reporter, :sqs_batch_wrapper, :enrollment_pipeline

    delegate :report_error, to: :error_reporter
    delegate :delete_message_batch, to: :sqs_batch_wrapper
    delegate :process_message, to: :enrollment_pipeline

    # Delete messages from the queue and report deletion errors
    # @param [Array<Aws::SQS::Types::Message>] deletion_batch SQS messages to delete
    # @return [Integer] Number of items deleted
    def process_deletions(deletion_batch)
      return 0 if deletion_batch.empty?

      delete_result = delete_message_batch(deletion_batch)
      delete_result.failed.each do |error_entry|
        report_error(
          'Failed to delete item from queue',
          sqs_delete_error: error_entry.to_h,
        )
      end
      delete_result.successful.size
    rescue StandardError => err
      report_error(err)
      0
    end
  end
end
