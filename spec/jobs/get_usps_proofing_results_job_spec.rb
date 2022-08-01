require 'rails_helper'

RSpec.describe GetUspsProofingResultsJob do
  include UspsIppHelper

  let(:job) { GetUspsProofingResultsJob.new }
  let(:job_analytics) { FakeAnalytics.new }

  before do
    allow(job).to receive(:analytics).and_return(job_analytics)
  end

  describe '#perform' do
    describe 'IPP enabled' do
      # this passing enrollment shouldn't be included when the job collects
      # enrollments that need their status checked
      let!(:passed_enrollment) { create(:in_person_enrollment, :passed) }

      let!(:pending_enrollment) do
        create(
          :in_person_enrollment,
          status: :pending,
          enrollment_code: SecureRandom.hex(16),
          selected_location_details: { name: 'FRIENDSHIP' },
        )
      end
      let!(:pending_enrollment_2) do
        create(
          :in_person_enrollment,
          status: :pending,
          enrollment_code: SecureRandom.hex(16),
          selected_location_details: { name: 'BALTIMORE' },
        )
      end
      let!(:pending_enrollment_3) do
        create(
          :in_person_enrollment,
          status: :pending,
          enrollment_code: SecureRandom.hex(16),
          selected_location_details: { name: 'WASHINGTON' },
        )
      end
      let!(:pending_enrollment_4) do
        create(
          :in_person_enrollment,
          status: :pending,
          enrollment_code: SecureRandom.hex(16),
          selected_location_details: { name: 'ARLINGTON' },
        )
      end
      let(:pending_enrollments) do
        [
          pending_enrollment,
          pending_enrollment_2,
          pending_enrollment_3,
          pending_enrollment_4,
        ]
      end

      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      end

      it 'requests the enrollments that need their status checked' do
        stub_request_token
        stub_request_passed_proofing_results

        allow(InPersonEnrollment).to receive(:needs_usps_status_check).and_return([])

        job.perform(Time.zone.now)

        failure_message = 'expected call to InPersonEnrollment#needs_usps_status_check' \
          ' with beginless range starting about 5 minutes ago'
        expect(InPersonEnrollment).to(
          have_received(:needs_usps_status_check).
            with(
              satisfy { |v| v.begin.nil? && v.end > 5.25.minutes.ago && v.end < 4.75.minutes.ago },
            ),
          failure_message,
        )
      end

      it 'records the last attempted status check regardless of response code and contents' do
        stub_request_token
        stub_request_proofing_results_with_responses(
          request_failed_proofing_results_args,
          request_in_progress_proofing_results_args,
          request_in_progress_proofing_results_args,
          request_failed_proofing_results_args,
        )

        expect(pending_enrollments.pluck(:status_check_attempted_at)).to(
          all(eq nil),
          'failed test precondition: pending enrollments must not have status check time set',
        )

        start_time = Time.zone.now

        job.perform(Time.zone.now)

        expected_range = start_time...(Time.zone.now)

        failure_message = 'job must update status check time for all pending enrollments'
        expect(
          pending_enrollments.
            map(&:reload).
            pluck(:status_check_attempted_at),
        ).to(
          all(
            satisfy { |i| expected_range.cover?(i) },
          ),
          failure_message,
        )
      end

      it 'logs details about failed requests' do
        stub_request_token
        stub_request_failed_proofing_results

        allow(InPersonEnrollment).to receive(:needs_usps_status_check).
          and_return([pending_enrollment])

        job.perform(Time.zone.now)

        pending_enrollment.reload

        expect(pending_enrollment.failed?).to be_truthy

        expect(job_analytics).to have_logged_event(
          'GetUspsProofingResultsJob: Enrollment failed proofing',
          reason: 'Failed status',
          enrollment_id: pending_enrollment.id,
          enrollment_code: pending_enrollment.enrollment_code,
          failure_reason: 'Clerk indicates that ID name or address does not match source data.',
          fraud_suspected: false,
          primary_id_type: 'Uniformed Services identification card',
          proofing_state: 'PA',
          secondary_id_type: 'Deed of Trust',
          transaction_end_date_time: '12/17/2020 034055',
          transaction_start_date_time: '12/17/2020 033855',
        )
      end

      it 'updates enrollment records and activates profiles on 2xx responses with valid JSON' do
        stub_request_token
        stub_request_passed_proofing_results

        start_time = Time.zone.now

        job.perform(Time.zone.now)

        expected_range = start_time...(Time.zone.now)

        pending_enrollments.each do |enrollment|
          enrollment.reload
          expect(enrollment.passed?).to be_truthy
          expect(enrollment.status_updated_at).to satisfy do |timestamp|
            expected_range.cover?(timestamp)
          end
          expect(enrollment.profile.active).to be(true)

          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Enrollment passed proofing',
            reason: 'Successful status update',
            enrollment_id: enrollment.id,
            enrollment_code: enrollment.enrollment_code,
          )
        end
      end

      it 'sends verifed email on 2xx responses with valid JSON' do
        stub_request_token
        stub_request_passed_proofing_results

        allow(InPersonEnrollment).to receive(:needs_usps_status_check).
          and_return([pending_enrollment])

        mailer = instance_double(ActionMailer::MessageDelivery, deliver_now_or_later: true)
        user = pending_enrollment.user
        user.email_addresses.each do |email_address|
          expect(UserMailer).to receive(:in_person_verified).
            with(
              user,
              email_address,
              enrollment: instance_of(InPersonEnrollment),
            ).
            and_return(mailer)
        end

        job.perform(Time.zone.now)
      end

      it 'receives a non-hash value' do
        stub_request_token
        stub_request_proofing_results_with_responses({})

        job.perform(Time.zone.now)

        expect(job_analytics).to have_logged_event(
          'GetUspsProofingResultsJob: Exception raised',
          reason: 'Bad response structure',
          enrollment_id: pending_enrollment.id,
          enrollment_code: pending_enrollment.enrollment_code,
        )
      end

      it 'receives an unsupported status' do
        stub_request_token
        stub_request_passed_proofing_unsupported_status_results

        allow(InPersonEnrollment).to receive(:needs_usps_status_check).
          and_return([pending_enrollment])

        job.perform(Time.zone.now)

        pending_enrollment.reload

        expect(pending_enrollment.pending?).to be_truthy

        expect(job_analytics).to have_logged_event(
          'GetUspsProofingResultsJob: Enrollment failed proofing',
          reason: 'Unsupported status',
          enrollment_id: pending_enrollment.id,
          enrollment_code: pending_enrollment.enrollment_code,
          status: 'Not supported',
        )
      end

      it 'reports a high-priority error on 2xx responses with invalid JSON' do
        stub_request_token
        stub_request_proofing_results_with_invalid_response

        allow(InPersonEnrollment).to receive(:needs_usps_status_check).
          and_return([pending_enrollment])

        job.perform(Time.zone.now)

        pending_enrollment.reload

        expect(pending_enrollment.pending?).to be_truthy

        expect(job_analytics).to have_logged_event(
          'GetUspsProofingResultsJob: Exception raised',
          reason: 'Request exception',
          enrollment_id: pending_enrollment.id,
          enrollment_code: pending_enrollment.enrollment_code,
        )
      end

      it 'reports a low-priority error on 4xx responses' do
        stub_request_token
        stub_request_proofing_results_with_responses({ status: 400 })

        allow(InPersonEnrollment).to receive(:needs_usps_status_check).
          and_return([pending_enrollment])

        job.perform(Time.zone.now)

        pending_enrollment.reload

        expect(pending_enrollment.pending?).to be_truthy

        expect(job_analytics).to have_logged_event(
          'GetUspsProofingResultsJob: Exception raised',
          reason: 'Request exception',
          enrollment_id: pending_enrollment.id,
          enrollment_code: pending_enrollment.enrollment_code,
        )
      end

      it 'marks enrollments as expired when USPS says they have expired' do
        stub_request_token
        stub_request_expired_proofing_results

        job.perform(Time.zone.now)

        pending_enrollments.each do |enrollment|
          enrollment.reload
          expect(enrollment.expired?).to be_truthy
        end
      end

      it 'ignores enrollments when USPS says the customer has not been to the post office' do
        stub_request_token
        stub_request_in_progress_proofing_results

        job.perform(Time.zone.now)

        pending_enrollments.each do |enrollment|
          enrollment.reload
          expect(enrollment.pending?).to be_truthy
        end
      end

      it 'reports a high-priority error on 5xx responses' do
        stub_request_token
        stub_request_proofing_results_with_responses({ status: 500 })

        allow(InPersonEnrollment).to receive(:needs_usps_status_check).
          and_return([pending_enrollment])

        job.perform(Time.zone.now)

        pending_enrollment.reload

        expect(pending_enrollment.pending?).to be_truthy

        expect(job_analytics).to have_logged_event(
          'GetUspsProofingResultsJob: Exception raised',
          reason: 'Request exception',
          enrollment_id: pending_enrollment.id,
          enrollment_code: pending_enrollment.enrollment_code,
        )
      end

      it 'fails enrollment for unsupported ID types' do
        stub_request_token
        stub_request_passed_proofing_unsupported_id_results

        allow(InPersonEnrollment).to receive(:needs_usps_status_check).
          and_return([pending_enrollment])

        expect(pending_enrollment.pending?).to be_truthy

        job.perform Time.zone.now

        expect(pending_enrollment.reload.failed?).to be_truthy

        expect(job_analytics).to have_logged_event(
          'GetUspsProofingResultsJob: Enrollment failed proofing',
          reason: 'Unsupported ID type',
          enrollment_id: pending_enrollment.id,
          enrollment_code: pending_enrollment.enrollment_code,
          primary_id_type: 'Not supported',
        )
      end
    end

    describe 'IPP disabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(false)
      end

      it 'does not request any enrollment records' do
        # no stubbing means this test will fail if the UspsInPersonProofing::Proofer
        # tries to connect to the USPS API
        job.perform Time.zone.now
      end
    end
  end
end
