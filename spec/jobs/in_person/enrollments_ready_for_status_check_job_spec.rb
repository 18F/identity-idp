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
end
