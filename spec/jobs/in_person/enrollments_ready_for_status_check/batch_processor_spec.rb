require 'rails_helper'

RSpec.describe InPerson::EnrollmentsReadyForStatusCheck::BatchProcessor do
  let(:messages) { [] }
  let(:analytics_stats) do
    {
      fetched_items: 0,
      processed_items: 0,
      deleted_items: 0,
      valid_items: 0,
      invalid_items: 0,
    }
  end

  let(:error_reporter) { instance_double(InPerson::EnrollmentsReadyForStatusCheck::ErrorReporter) }
  let(:sqs_batch_wrapper) do
    instance_double(InPerson::EnrollmentsReadyForStatusCheck::SqsBatchWrapper)
  end
  let(:enrollment_pipeline) do
    instance_double(InPerson::EnrollmentsReadyForStatusCheck::EnrollmentPipeline)
  end

  subject(:batch_processor) do
    described_class.new(
      error_reporter:,
      sqs_batch_wrapper:,
      enrollment_pipeline:,
    )
  end

  describe '#process_batch' do
    let(:delete_result) { instance_double(Aws::SQS::Types::DeleteMessageBatchResult) }

    def successful_delete
      instance_double(Aws::SQS::Types::DeleteMessageBatchResultEntry)
    end

    def failed_delete
      instance_double(Aws::SQS::Types::BatchResultErrorEntry)
    end

    it 'ignores an empty batch' do
      expect(enrollment_pipeline).not_to receive(:process_message)
      expect(sqs_batch_wrapper).not_to receive(:delete_message_batch)
      expect(error_reporter).not_to receive(:report_error)
      expected_analytics_stats = analytics_stats.dup
      batch_processor.process_batch(messages, analytics_stats)
      expect(analytics_stats).to eq(expected_analytics_stats)
    end

    context 'one message' do
      let(:message) { instance_double(Aws::SQS::Types::Message) }
      let(:messages) { [message] }

      it 'unhandled exception does not delete item' do
        error = RuntimeError.new 'test error'
        expect(enrollment_pipeline).to receive(:process_message).with(message).and_raise(error).once
        expect(sqs_batch_wrapper).not_to receive(:delete_message_batch)
        expect(error_reporter).not_to receive(:report_error)
        expected_analytics_stats = {
          **analytics_stats,
          fetched_items: 1,
        }
        expect do
          batch_processor.process_batch(messages, analytics_stats)
        end.to raise_error(error)
        expect(analytics_stats).to eq(expected_analytics_stats)
      end

      it 'invalid item is marked as processed and deleted' do
        expect(enrollment_pipeline).to receive(:process_message)
          .with(message).and_return(false).once
        expect(sqs_batch_wrapper).to receive(:delete_message_batch)
          .with(messages).and_return(delete_result).once
        expect(delete_result).to receive(:failed).and_return([])
        expect(delete_result).to receive(:successful).and_return(messages)
        expect(error_reporter).not_to receive(:report_error)
        expected_analytics_stats = {
          **analytics_stats,
          fetched_items: 1,
          invalid_items: 1,
          deleted_items: 1,
          processed_items: 1,
        }
        batch_processor.process_batch(messages, analytics_stats)
        expect(analytics_stats).to eq(expected_analytics_stats)
      end

      it 'valid item is marked as processed and deleted' do
        expect(enrollment_pipeline).to receive(:process_message)
          .with(message).and_return(true).once
        expect(sqs_batch_wrapper).to receive(:delete_message_batch)
          .with(messages).and_return(delete_result).once
        expect(delete_result).to receive(:failed).and_return([])
        expect(delete_result).to receive(:successful).and_return(
          [
            successful_delete,
          ],
        )
        expect(error_reporter).not_to receive(:report_error)
        expected_analytics_stats = {
          **analytics_stats,
          fetched_items: 1,
          valid_items: 1,
          deleted_items: 1,
          processed_items: 1,
        }
        batch_processor.process_batch(messages, analytics_stats)
        expect(analytics_stats).to eq(expected_analytics_stats)
      end

      it 'item is marked as processed but fails to be deleted' do
        expect(enrollment_pipeline).to receive(:process_message)
          .with(message).and_return(true).once
        expect(sqs_batch_wrapper).to receive(:delete_message_batch)
          .with(messages).and_return(delete_result).once
        error_entry = failed_delete
        expect(delete_result).to receive(:failed).and_return(
          [
            error_entry,
          ],
        )
        error_entry_hash = {
          id: 123,
        }
        expect(error_entry).to receive(:to_h).and_return(error_entry_hash)
        expect(delete_result).to receive(:successful).and_return([])
        expect(error_reporter).to receive(:report_error).with(
          'Failed to delete item from queue',
          sqs_delete_error: error_entry_hash,
        ).once
        expected_analytics_stats = {
          **analytics_stats,
          fetched_items: 1,
          valid_items: 1,
          deleted_items: 0,
          processed_items: 1,
        }
        batch_processor.process_batch(messages, analytics_stats)
        expect(analytics_stats).to eq(expected_analytics_stats)
      end

      it 'item is marked as processed but the batch delete call throws an error' do
        error = RuntimeError.new 'test batch error'
        expect(enrollment_pipeline).to receive(:process_message)
          .with(message).and_return(true).once
        expect(sqs_batch_wrapper).to receive(:delete_message_batch)
          .with(messages).and_raise(error).once
        expect(error_reporter).to receive(:report_error).with(error).once
        expected_analytics_stats = {
          **analytics_stats,
          fetched_items: 1,
          valid_items: 1,
          deleted_items: 0,
          processed_items: 1,
        }
        batch_processor.process_batch(messages, analytics_stats)
        expect(analytics_stats).to eq(expected_analytics_stats)
      end
    end

    context 'multiple messages' do
      let(:message) { instance_double(Aws::SQS::Types::Message) }
      let(:messages) do
        [
          instance_double(Aws::SQS::Types::Message),
          instance_double(Aws::SQS::Types::Message),
          instance_double(Aws::SQS::Types::Message),
          instance_double(Aws::SQS::Types::Message),
          instance_double(Aws::SQS::Types::Message),
        ]
      end

      it 'handles combined valid, invalid, and non-deleted messages' do
        expect(enrollment_pipeline).to receive(:process_message).and_return(
          true,
          false,
          true,
          true,
          true,
        ).exactly(5).times
        expect(sqs_batch_wrapper).to receive(:delete_message_batch)
          .with(messages).and_return(delete_result).once

        error_entry = failed_delete
        error_entry2 = failed_delete
        expect(delete_result).to receive(:failed).and_return(
          [
            error_entry,
            error_entry2,
          ],
        )
        error_entry_hash = {
          id: 123,
        }
        error_entry_hash2 = {
          id: 456,
        }
        expect(error_entry).to receive(:to_h).and_return(error_entry_hash)
        expect(error_entry2).to receive(:to_h).and_return(error_entry_hash2)
        expect(delete_result).to receive(:successful).and_return(
          [
            successful_delete,
            successful_delete,
            successful_delete,
          ],
        )
        expect(error_reporter).to receive(:report_error).with(
          'Failed to delete item from queue',
          sqs_delete_error: error_entry_hash,
        ).once
        expect(error_reporter).to receive(:report_error).with(
          'Failed to delete item from queue',
          sqs_delete_error: error_entry_hash2,
        ).once
        expected_analytics_stats = {
          **analytics_stats,
          fetched_items: 5,
          valid_items: 4,
          invalid_items: 1,
          deleted_items: 3,
          processed_items: 5,
        }
        batch_processor.process_batch(messages, analytics_stats)
        expect(analytics_stats).to eq(expected_analytics_stats)
      end
    end
  end
end
