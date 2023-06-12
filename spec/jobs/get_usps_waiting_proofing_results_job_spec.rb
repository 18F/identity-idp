require 'rails_helper'

RSpec.describe GetUspsWaitingProofingResultsJob do
  include UspsIppHelper
  include ApproximatingHelper

  let(:reprocess_delay_minutes) { 2.0 }
  let(:request_delay_ms) { 0 }
  let(:job) { GetUspsWaitingProofingResultsJob.new }
  let(:job_analytics) { FakeAnalytics.new }
  let(:transaction_start_date_time) do
    ActiveSupport::TimeZone[-6].strptime(
      '12/17/2020 033855',
      '%m/%d/%Y %H%M%S',
    ).in_time_zone('UTC')
  end
  let(:transaction_end_date_time) do
    ActiveSupport::TimeZone[-6].strptime(
      '12/17/2020 034055',
      '%m/%d/%Y %H%M%S',
    ).in_time_zone('UTC')
  end

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
    if respond_to?(:pending_enrollment)
      pending_enrollment.update(enrollment_established_at: 3.days.ago)
    end
  end

  describe '#perform' do
    describe 'IPP enabled' do
      describe 'Ready Job enabled' do
        let!(:pending_enrollments) do
          [
            create(
              :in_person_enrollment, :pending,
              selected_location_details: { name: 'BALTIMORE' },
              issuer: 'http://localhost:3000',
              ready_for_status_check: false
            ),
            create(
              :in_person_enrollment, :pending,
              selected_location_details: { name: 'FRIENDSHIP' },
              ready_for_status_check: false
            ),
            create(
              :in_person_enrollment, :pending,
              selected_location_details: { name: 'WASHINGTON' },
              ready_for_status_check: false
            ),
            create(
              :in_person_enrollment, :pending,
              selected_location_details: { name: 'ARLINGTON' },
              ready_for_status_check: false
            ),
            create(
              :in_person_enrollment, :pending,
              selected_location_details: { name: 'DEANWOOD' },
              ready_for_status_check: false
            ),
          ]
        end
        let(:pending_enrollment) { pending_enrollments[0] }

        before do
          allow(InPersonEnrollment).to receive(:needs_status_check_on_waiting_enrollments).
            and_return([pending_enrollment])
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          allow(IdentityConfig.store).to(
            receive(:in_person_enrollments_ready_job_enabled).and_return(true),
          )
        end

        it 'requests the enrollments that need their status checked' do
          stub_request_passed_proofing_results

          freeze_time do
            job.perform(Time.zone.now)

            expect(InPersonEnrollment).to(
              have_received(:needs_status_check_on_waiting_enrollments).
              with(...reprocess_delay_minutes.minutes.ago),
            )
          end
        end

        it 'records the last attempted status check regardless of response code and contents' do
          allow(InPersonEnrollment).to receive(:needs_status_check_on_waiting_enrollments).
            and_return(pending_enrollments)
          stub_request_proofing_results_with_responses(
            request_failed_proofing_results_args,
            request_in_progress_proofing_results_args,
            request_in_progress_proofing_results_args,
            request_failed_proofing_results_args,
          )

          expect(pending_enrollments.pluck(:status_check_attempted_at)).to(
            all(eq nil),
            'failed test precondition:
              pending enrollments must not set status check attempted time',
          )

          expect(pending_enrollments.pluck(:status_check_completed_at)).to(
            all(eq nil),
            'failed test precondition:
              pending enrollments must not set status check completed time',
          )

          freeze_time do
            job.perform(Time.zone.now)

            expect(
              pending_enrollments.
                map(&:reload).
                pluck(:status_check_attempted_at),
            ).to(
              all(eq Time.zone.now),
              'job must update status check attempted time for all pending enrollments',
            )

            expect(
              pending_enrollments.
                map(&:reload).
                pluck(:status_check_completed_at),
            ).to(
              all(eq Time.zone.now),
              'job must update status check completed time for all pending enrollments',
            )
          end
        end

        it 'logs a message when the job starts' do
          allow(InPersonEnrollment).to receive(:needs_status_check_on_waiting_enrollments).
            and_return(pending_enrollments)
          stub_request_proofing_results_with_responses(
            request_failed_proofing_results_args,
            request_in_progress_proofing_results_args,
            request_in_progress_proofing_results_args,
            request_failed_proofing_results_args,
          )

          job.perform(Time.zone.now)

          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Job started',
            enrollments_count: 5,
            reprocess_delay_minutes: 2.0,
            job_name: 'GetUspsWaitingProofingResultsJob',
          )
        end

        it 'logs a message with counts of various outcomes when the job completes (errored > 0)' do
          allow(InPersonEnrollment).to receive(:needs_status_check_on_waiting_enrollments).
            and_return(pending_enrollments)
          stub_request_proofing_results_with_responses(
            request_passed_proofing_results_args,
            request_in_progress_proofing_results_args,
            { status: 500 },
            request_failed_proofing_results_args,
            request_expired_proofing_results_args,
          )

          job.perform(Time.zone.now)

          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Job completed',
            duration_seconds: anything,
            enrollments_checked: 5,
            enrollments_errored: 1,
            enrollments_expired: 1,
            enrollments_failed: 1,
            enrollments_in_progress: 1,
            enrollments_passed: 1,
            percent_enrollments_errored: 20.00,
            job_name: 'GetUspsWaitingProofingResultsJob',
          )

          expect(
            job_analytics.events['GetUspsProofingResultsJob: Job completed'].
              first[:duration_seconds],
          ).to be >= 0.0
        end

        it 'logs a message with counts of various outcomes when the job completes (errored = 0)' do
          allow(InPersonEnrollment).to receive(:needs_status_check_on_waiting_enrollments).
            and_return(pending_enrollments)
          stub_request_proofing_results_with_responses(
            request_passed_proofing_results_args,
          )

          job.perform(Time.zone.now)

          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Job completed',
            duration_seconds: anything,
            enrollments_checked: 5,
            enrollments_errored: 0,
            enrollments_expired: 0,
            enrollments_failed: 0,
            enrollments_in_progress: 0,
            enrollments_passed: 5,
            percent_enrollments_errored: 0.00,
            job_name: 'GetUspsWaitingProofingResultsJob',
          )

          expect(
            job_analytics.events['GetUspsProofingResultsJob: Job completed'].
              first[:duration_seconds],
          ).to be >= 0.0
        end

        it 'logs a message with counts of various outcomes when the job completes
          (no enrollments)' do
          allow(InPersonEnrollment).to receive(:needs_status_check_on_waiting_enrollments).
            and_return([])
          stub_request_proofing_results_with_responses(
            request_passed_proofing_results_args,
          )

          job.perform(Time.zone.now)

          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Job completed',
            duration_seconds: anything,
            enrollments_checked: 0,
            enrollments_errored: 0,
            enrollments_expired: 0,
            enrollments_failed: 0,
            enrollments_in_progress: 0,
            enrollments_passed: 0,
            percent_enrollments_errored: 0.00,
            job_name: 'GetUspsWaitingProofingResultsJob',
          )

          expect(
            job_analytics.events['GetUspsProofingResultsJob: Job completed'].
              first[:duration_seconds],
          ).to be >= 0.0
        end
      end
    end

    describe 'IPP disabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(false)
        allow(IdentityConfig.store).to(
          receive(:in_person_enrollments_ready_job_enabled).and_return(true),
        )
        allow(IdentityConfig.store).to receive(:usps_mock_fallback).and_return(false)
      end

      it 'does not request any enrollment records' do
        # no stubbing means this test will fail if the UspsInPersonProofing::Proofer
        # tries to connect to the USPS API
        job.perform Time.zone.now
      end
    end

    describe 'Ready Job disabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
        allow(IdentityConfig.store).to(
          receive(:in_person_enrollments_ready_job_enabled).and_return(false),
        )
        allow(IdentityConfig.store).to receive(:usps_mock_fallback).and_return(false)
      end

      it 'does not request any enrollment records' do
        # no stubbing means this test will fail if the UspsInPersonProofing::Proofer
        # tries to connect to the USPS API
        job.perform Time.zone.now
      end
    end
  end
end
