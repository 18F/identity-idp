require 'rails_helper'

RSpec.describe GetUspsWaitingProofingResultsJob do
  include UspsIppHelper

  let(:reprocess_delay_minutes) { 2.0 }
  let(:request_delay_ms) { 0 }
  let(:job) { described_class.new }
  let(:job_analytics) { FakeAnalytics.new }

  before do
    allow(Rails).to receive(:cache).and_return(
      ActiveSupport::Cache::RedisCacheStore.new(url: IdentityConfig.store.redis_throttle_url),
    )
    ActiveJob::Base.queue_adapter = :test
    allow(job).to receive(:analytics).and_return(job_analytics)
    allow(IdentityConfig.store).to receive(:get_usps_proofing_results_job_reprocess_delay_minutes).
      and_return(reprocess_delay_minutes)
    stub_const(
      'GetUspsProofingResultsJob::REQUEST_DELAY_IN_SECONDS',
      request_delay_ms / GetUspsProofingResultsJob::MILLISECONDS_PER_SECOND,
    )
    stub_request_token
  end

  describe '#perform' do
    describe 'IPP and Ready Job enabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
        allow(IdentityConfig.store).to(
          receive(:in_person_enrollments_ready_job_enabled).and_return(true),
        )
      end

      it 'requests the enrollments that need their status checked' do
        freeze_time do
          expect(InPersonEnrollment).to(
            receive(:needs_status_check_on_waiting_enrollments).
            with(...reprocess_delay_minutes.minutes.ago).
            and_return(InPersonEnrollment.all),
          )

          job.perform(Time.zone.now)
        end
      end

      it 'processes the correct enrollments and logs the correct job name and enrollment count' do
        # 6 "waiting" enrollments
        create_list(:in_person_enrollment, 6, :pending, ready_for_status_check: false)
        waiting_ids = InPersonEnrollment.last(6).pluck(:id)
        # 6 not "waiting" enrollments
        create_list(:in_person_enrollment, 2, :establishing, ready_for_status_check: false)
        create_list(:in_person_enrollment, 2, :pending, ready_for_status_check: true)
        create_list(
          :in_person_enrollment,
          2,
          :pending,
          ready_for_status_check: false,
          last_batch_claimed_at: 1.minute.ago,
        )

        job.perform(Time.zone.now)

        expect(InPersonEnrollment.where.not(status_check_attempted_at: nil).pluck(:id)).
          to(match_array(waiting_ids))
        expect(job_analytics).to have_logged_event(
          'GetUspsProofingResultsJob: Job started',
          enrollments_count: 6,
          reprocess_delay_minutes: 2.0,
          job_name: 'GetUspsWaitingProofingResultsJob',
        )
      end
    end

    describe 'IPP disabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(false)
        allow(IdentityConfig.store).to(
          receive(:in_person_enrollments_ready_job_enabled).and_return(true),
        )
      end

      it 'does not request any enrollment records' do
        job.perform Time.zone.now

        expect(job_analytics).not_to have_logged_event('GetUspsProofingResultsJob: Job started')
      end
    end

    describe 'Ready Job disabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
        allow(IdentityConfig.store).to(
          receive(:in_person_enrollments_ready_job_enabled).and_return(false),
        )
      end

      it 'does not request any enrollment records' do
        job.perform Time.zone.now

        expect(job_analytics).not_to have_logged_event('GetUspsProofingResultsJob: Job started')
      end
    end
  end
end
