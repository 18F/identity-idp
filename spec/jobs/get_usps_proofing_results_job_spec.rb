require 'rails_helper'

RSpec.describe GetUspsProofingResultsJob do
  include UspsIppHelper

  let(:job) { GetUspsProofingResultsJob.new }

  describe '#perform' do
    describe 'IPP enabled' do
      # this passing enrollment shouldn't be included when the job collects
      # enrollments that need their status checked
      let!(:passed_enrollment) { create(:in_person_enrollment, :passed) }

      let!(:pending_enrollment) do
        create(:in_person_enrollment, status: :pending, enrollment_code: SecureRandom.hex(16))
      end
      let!(:pending_enrollment_2) do
        create(:in_person_enrollment, status: :pending, enrollment_code: SecureRandom.hex(16))
      end
      let!(:pending_enrollment_3) do
        create(:in_person_enrollment, status: :pending, enrollment_code: SecureRandom.hex(16))
      end
      let!(:pending_enrollment_4) do
        create(:in_person_enrollment, status: :pending, enrollment_code: SecureRandom.hex(16))
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

        # see request_failed_proofing_supported_id_results_response.json
        expect(IdentityJobLogSubscriber.logger).to receive(:warn).
            with(
              satisfy do |event|
                expect(event).to be_instance_of(String)
                parsed_event = JSON.parse(event)
                expect(parsed_event).to be_instance_of(Hash).
                and include(
                  'name' => 'get_usps_proofing_results_job.errors.failed_status',
                  'enrollment_id' => pending_enrollment.id,
                  'failure_reason' => 'Clerk indicates that ID name or address' \
                                      ' does not match source data.',
                  'fraud_suspected' => false,
                  'primary_id_type' => 'Uniformed Services identification card',
                  'proofing_city' => 'WILKES BARRE',
                  'proofing_confirmation_number' => '350040248346707',
                  'proofing_post_office' => 'WILKES BARRE',
                  'proofing_state' => 'PA',
                  'secondary_id_type' => 'Deed of Trust',
                  'transaction_end_date_time' => '12/17/2020 034055',
                  'transaction_start_date_time' => '12/17/2020 033855',
                )
              end,
            )

        job.perform(Time.zone.now)

        pending_enrollment.reload

        expect(pending_enrollment.failed?).to be_truthy
      end

      it 'updates enrollment records on 2xx responses with valid JSON' do
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
        end
      end

      it 'reports a high-priority error on 2xx responses with invalid JSON' do
        stub_request_token
        stub_request_proofing_results_with_invalid_response

        allow(InPersonEnrollment).to receive(:needs_usps_status_check).
              and_return([pending_enrollment])

        expect(IdentityJobLogSubscriber.logger).to receive(:error).
            with(
              satisfy do |event|
                expect(event).to be_instance_of(String)
                parsed_event = JSON.parse(event)
                expect(parsed_event).to be_instance_of(Hash).
                and include(
                  'name' => 'get_usps_proofing_results_job.errors.request_exception',
                  'enrollment_id' => pending_enrollment.id,
                )
              end,
            )

        job.perform(Time.zone.now)

        pending_enrollment.reload

        expect(pending_enrollment.pending?).to be_truthy
      end

      it 'reports a low-priority error on 4xx responses' do
        stub_request_token
        stub_request_proofing_results_with_responses({ status: 400 })

        allow(InPersonEnrollment).to receive(:needs_usps_status_check).
              and_return([pending_enrollment])

        expect(IdentityJobLogSubscriber.logger).to receive(:warn).
            with(
              satisfy do |event|
                expect(event).to be_instance_of(String)
                parsed_event = JSON.parse(event)
                expect(parsed_event).to be_instance_of(Hash).
                and include(
                  'name' => 'get_usps_proofing_results_job.errors.request_exception',
                  'enrollment_id' => pending_enrollment.id,
                )
              end,
            )

        job.perform(Time.zone.now)

        pending_enrollment.reload

        expect(pending_enrollment.pending?).to be_truthy
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

        expect(IdentityJobLogSubscriber.logger).to receive(:error).
            with(
              satisfy do |event|
                expect(event).to be_instance_of(String)
                parsed_event = JSON.parse(event)
                expect(parsed_event).to be_instance_of(Hash).
                and include(
                  'name' => 'get_usps_proofing_results_job.errors.request_exception',
                  'enrollment_id' => pending_enrollment.id,
                )
              end,
            )

        job.perform(Time.zone.now)

        pending_enrollment.reload

        expect(pending_enrollment.pending?).to be_truthy
      end

      it 'fails enrollment for unsupported ID types' do
        stub_request_token
        stub_request_passed_proofing_unsupported_id_results

        allow(InPersonEnrollment).to receive(:needs_usps_status_check).
              and_return([pending_enrollment])

        expect(IdentityJobLogSubscriber.logger).to receive(:warn).
            with(
              satisfy do |event|
                expect(event).to be_instance_of(String)
                parsed_event = JSON.parse(event)
                expect(parsed_event).to be_instance_of(Hash).
                and include(
                  'name' => 'get_usps_proofing_results_job.errors.unsupported_id_type',
                  'enrollment_id' => pending_enrollment.id,
                  'primary_id_type' => 'Not supported',
                )
              end,
            )

        expect(pending_enrollment.pending?).to be_truthy

        job.perform Time.zone.now

        expect(pending_enrollment.reload.failed?).to be_truthy
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
