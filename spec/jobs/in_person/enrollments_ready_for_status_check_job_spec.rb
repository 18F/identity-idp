require 'rails_helper'

RSpec.describe InPerson::EnrollmentsReadyForStatusCheckJob do
  let(:in_person_proofing_enabled) { nil }
  let(:in_person_enrollments_ready_job_enabled) { nil }
  let(:analytics) { FakeAnalytics.new }
  subject(:job) { described_class.new }

  describe '#perform' do
    before(:each) do
      allow(job).to receive(:analytics).and_return(analytics)
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
        and_return(in_person_proofing_enabled)
      allow(IdentityConfig.store).to receive(:in_person_enrollments_ready_job_enabled).
        and_return(in_person_enrollments_ready_job_enabled)
    end

    def process_batch_result
      {
        fetched_items: 7,
        processed_items: 7,
        deleted_items: 4,
        valid_items: 5,
        invalid_items: 2,
      }
    end

    def new_message
      instance_double(Aws::SQS::Types::Message)
    end

    context 'in person proofing disabled' do
      let(:in_person_proofing_enabled) { false }
      let(:in_person_enrollments_ready_job_enabled) { true }
      it 'returns true without doing anything' do
        expect(analytics).not_to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_started,
        )
        expect(analytics).not_to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_completed,
        )
        expect(job).not_to receive(:poll)
        expect(job).not_to receive(:process_batch)
        expect(job.perform(Time.zone.now)).to be(true)
      end
    end

    context 'job disabled' do
      let(:in_person_proofing_enabled) { true }
      let(:in_person_enrollments_ready_job_enabled) { false }
      it 'returns true without doing anything' do
        expect(analytics).not_to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_started,
        )
        expect(analytics).not_to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_completed,
        )
        expect(job).not_to receive(:poll)
        expect(job).not_to receive(:process_batch)
        expect(job.perform(Time.zone.now)).to be(true)
      end
    end

    context 'in person proofing and job enabled' do
      let(:in_person_proofing_enabled) { true }
      let(:in_person_enrollments_ready_job_enabled) { true }

      it 'logs analytics for a run with zero batches' do
        expect(job).to receive(:poll).and_return([])
        expect(analytics).to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_started,
        )
        expect(analytics).to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_completed,
        ).with(
          fetched_items: 0,
          processed_items: 0,
          deleted_items: 0,
          valid_items: 0,
          invalid_items: 0,
          incomplete_items: 0,
          deletion_failed_items: 0,
        )
        expect(job).not_to receive(:process_batch)
        expect(job.perform(Time.zone.now)).to be(true)
      end

      it 'logs analytics for a run with one batch' do
        batch = [new_message]
        expect(job).to receive(:poll).and_return(batch, [])
        expect(analytics).to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_started,
        )
        expect(job).to receive(:process_batch).with(
          batch,
          {
            fetched_items: 0,
            processed_items: 0,
            deleted_items: 0,
            valid_items: 0,
            invalid_items: 0,
          },
        ) do |_batch, analytics_stats|
          analytics_stats.merge!(process_batch_result)
        end.once
        expect(analytics).to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_completed,
        ).with(
          fetched_items: 7,
          processed_items: 7,
          deleted_items: 4,
          valid_items: 5,
          invalid_items: 2,
          incomplete_items: 0,
          deletion_failed_items: 3,
        )
        expect(job.perform(Time.zone.now)).to be(true)
      end

      it 'logs analytics for a run with one batch that throws an error' do
        batch = [new_message]
        expect(job).to receive(:poll).and_return(batch)
        expect(analytics).to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_started,
        )
        error = RuntimeError.new('test error')
        expect(job).to receive(:process_batch).with(
          batch,
          an_instance_of(Hash),
        ) do |_batch, analytics_stats|
          analytics_stats.merge!(process_batch_result)
          raise error
        end.once
        expect(analytics).to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_completed,
        ).with(
          fetched_items: 7,
          processed_items: 7,
          deleted_items: 4,
          valid_items: 5,
          invalid_items: 2,
          incomplete_items: 0,
          deletion_failed_items: 3,
        )
        expect { job.perform(Time.zone.now) }.to raise_error(error)
      end

      it 'logs analytics for a run with three batches' do
        batch = [new_message]
        batch2 = [new_message]
        batch3 = [new_message]
        expect(job).to receive(:poll).and_return(batch, batch2, batch3, [])
        expect(analytics).to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_started,
        )
        expect(job).to receive(:process_batch) do |current_batch, analytics_stats|
          if batch == current_batch
            process_batch_result.each do |key, value|
              analytics_stats[key] = value + analytics_stats[key]
            end
          elsif current_batch == batch2 || current_batch == batch3
            {
              fetched_items: 3,
              processed_items: 3,
              deleted_items: 2,
              valid_items: 3,
              invalid_items: 0,
            }.each do |key, value|
              analytics_stats[key] = value + analytics_stats[key]
            end
          end
        end.exactly(3).times
        expect(analytics).to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_completed,
        ).with(
          fetched_items: 13,
          processed_items: 13,
          deleted_items: 8,
          valid_items: 11,
          invalid_items: 2,
          incomplete_items: 0,
          deletion_failed_items: 5,
        )
        expect(job.perform(Time.zone.now)).to be(true)
      end

      it 'logs analytics for a run with three batches with error' do
        batch = [new_message]
        batch2 = [new_message]
        batch3 = [new_message]
        expect(job).to receive(:poll).and_return(batch, batch2, batch3)
        expect(analytics).to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_started,
        )
        error = RuntimeError.new('test error')
        expect(job).to receive(:process_batch) do |current_batch, analytics_stats|
          if current_batch == batch
            process_batch_result.each do |key, value|
              analytics_stats[key] = value + analytics_stats[key]
            end
          elsif current_batch == batch3
            {
              fetched_items: 3,
              processed_items: 1,
              deleted_items: 1,
              valid_items: 1,
              invalid_items: 0,
            }.each do |key, value|
              analytics_stats[key] = value + analytics_stats[key]
            end
            raise error
          elsif current_batch == batch2
            {
              fetched_items: 3,
              processed_items: 3,
              deleted_items: 2,
              valid_items: 3,
              invalid_items: 0,
            }.each do |key, value|
              analytics_stats[key] = value + analytics_stats[key]
            end
          end
        end.exactly(3).times
        expect(analytics).to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_completed,
        ).with(
          fetched_items: 13,
          processed_items: 11,
          deleted_items: 7,
          valid_items: 9,
          invalid_items: 2,
          incomplete_items: 2,
          deletion_failed_items: 4,
        )
        expect { job.perform(Time.zone.now) }.to raise_error(error)
      end
    end
  end

  # Normally we should stick to validating the contract and dependencies,
  # but making an exception here because the construction of these classes
  # is relatively complex; so expanding tests to additionally cover delegation
  # and constructor calls.
  #
  # Also doing this b/c the codebase does not use an IoC framework like dry-system
  # and there's not an established convention for creating factories.

  describe '#poll (private)' do
    it 'delegates to sqs_batch_wrapper' do
      sqs_batch_wrapper = instance_double(InPerson::EnrollmentsReadyForStatusCheck::SqsBatchWrapper)
      poll_result = []
      expect(job).to receive(:sqs_batch_wrapper).and_return(sqs_batch_wrapper)
      expect(sqs_batch_wrapper).to receive(:poll).and_return(poll_result).once
      expect(job.send(:poll)).to be(poll_result)
    end
  end

  describe '#process_batch (private)' do
    it 'delegates to batch_processor' do
      batch_processor = instance_double(InPerson::EnrollmentsReadyForStatusCheck::BatchProcessor)
      expect(job).to receive(:batch_processor).and_return(batch_processor)
      messages = []
      analytics_stats = {}
      expect(batch_processor).to receive(:process_batch).with(messages, analytics_stats).once
      job.send(:process_batch, messages, analytics_stats)
    end
  end

  describe '#analytics (private)' do
    it 'creates an analytics object' do
      analytics = FakeAnalytics.new
      expect(Analytics).to receive(:new).with(
        user: instance_of(AnonymousUser),
        request: nil,
        session: {},
        sp: nil,
      ).and_return(analytics)
      expect(job.send(:analytics)).to be(analytics)
    end
  end

  describe '#sqs_batch_wrapper (private)' do
    it 'creates SQS batch wrapper object with expected params' do
      sqs_client = instance_double(Aws::SQS::Client)

      queue_url = 'test/queue/url'
      max_number_of_messages = 10
      visibility_timeout_seconds = 30
      wait_time_seconds = 20
      aws_http_timeout = 5

      expect(Aws::SQS::Client).to receive(:new).
        with(http_read_timeout: wait_time_seconds + aws_http_timeout).
        and_return(sqs_client)

      expect(IdentityConfig.store).to receive_messages(
        aws_http_timeout:,
        in_person_enrollments_ready_job_queue_url: queue_url,
        in_person_enrollments_ready_job_max_number_of_messages: max_number_of_messages,
        in_person_enrollments_ready_job_visibility_timeout_seconds: visibility_timeout_seconds,
        in_person_enrollments_ready_job_wait_time_seconds: wait_time_seconds,
      )

      wrapper = instance_double(InPerson::EnrollmentsReadyForStatusCheck::SqsBatchWrapper)
      expect(InPerson::EnrollmentsReadyForStatusCheck::SqsBatchWrapper).to receive(:new).
        with(
          sqs_client:,
          queue_url:,
          receive_params: {
            queue_url:,
            max_number_of_messages:,
            visibility_timeout: visibility_timeout_seconds,
            wait_time_seconds:,
          },
        ).and_return(wrapper)
      expect(job.send(:sqs_batch_wrapper)).to be(wrapper)
    end
  end

  describe '#batch_processor (private)' do
    it 'creates a batch processor with the expected arguments' do
      analytics = FakeAnalytics.new
      expect(job).to receive(:analytics).and_return(analytics).exactly(2).times

      batch_processor_error_reporter = instance_double(
        InPerson::EnrollmentsReadyForStatusCheck::ErrorReporter,
      )
      expect(InPerson::EnrollmentsReadyForStatusCheck::ErrorReporter).to receive(:new).
        with(
          InPerson::EnrollmentsReadyForStatusCheck::BatchProcessor.name,
          analytics,
        ).and_return(batch_processor_error_reporter)

      sqs_batch_wrapper = instance_double(InPerson::EnrollmentsReadyForStatusCheck::SqsBatchWrapper)
      expect(job).to receive(:sqs_batch_wrapper).and_return(sqs_batch_wrapper)

      enrollment_pipeline_error_reporter = instance_double(
        InPerson::EnrollmentsReadyForStatusCheck::ErrorReporter,
      )
      expect(InPerson::EnrollmentsReadyForStatusCheck::ErrorReporter).to receive(:new).
        with(
          InPerson::EnrollmentsReadyForStatusCheck::EnrollmentPipeline.name,
          analytics,
        ).and_return(enrollment_pipeline_error_reporter)

      email_body_pattern = 'abcd'
      expect(IdentityConfig.store).to receive(:in_person_enrollments_ready_job_email_body_pattern).
        and_return(email_body_pattern)

      enrollment_pipeline = instance_double(
        InPerson::EnrollmentsReadyForStatusCheck::EnrollmentPipeline,
      )
      expect(InPerson::EnrollmentsReadyForStatusCheck::EnrollmentPipeline).to receive(:new).
        with(
          error_reporter: enrollment_pipeline_error_reporter,
          email_body_pattern: /abcd/,
        ).and_return(enrollment_pipeline)

      batch_processor = instance_double(InPerson::EnrollmentsReadyForStatusCheck::BatchProcessor)
      expect(InPerson::EnrollmentsReadyForStatusCheck::BatchProcessor).to receive(:new).
        with(
          error_reporter: batch_processor_error_reporter,
          sqs_batch_wrapper:,
          enrollment_pipeline:,
        ).and_return(batch_processor)

      expect(job.send(:batch_processor)).to be(batch_processor)
    end
  end
end
