require 'rails_helper'

RSpec.shared_examples 'enrollment with a status update' do |passed:, status:|
  it 'logs a message with common attributes' do
    freeze_time do
      pending_enrollment.update(
        enrollment_established_at: Time.zone.now - 3.days,
        status_check_attempted_at: Time.zone.now - 15.minutes,
        status_updated_at: Time.zone.now - 2.days,
      )

      job.perform(Time.zone.now)
    end

    expect(job_analytics).to have_logged_event(
      'GetUspsProofingResultsJob: Enrollment status updated',
      enrollment_code: pending_enrollment.enrollment_code,
      enrollment_id: pending_enrollment.id,
      minutes_since_last_status_check: 15.0,
      minutes_since_last_status_update: 2.days.in_minutes,
      minutes_to_completion: 3.days.in_minutes,
      passed: passed,
    )
  end

  it 'updates the status of the enrollment and profile appropriately' do
    freeze_time do
      pending_enrollment.update(
        status_check_attempted_at: Time.zone.now - 1.day,
        status_updated_at: Time.zone.now - 2.days,
      )
      job.perform(Time.zone.now)

      pending_enrollment.reload
      expect(pending_enrollment.status_updated_at).to eq(Time.zone.now)
      expect(pending_enrollment.status_check_attempted_at).to eq(Time.zone.now)
    end

    expect(pending_enrollment.status).to eq(status)

    expect(pending_enrollment.profile.active).to eq(passed)
  end
end

RSpec.shared_examples 'enrollment encountering an exception' do |exception_class: nil,
                                                                exception_message: nil,
                                                                reason: 'Request exception'|
  it 'logs an error message and leaves the enrollment and profile pending' do
    job.perform(Time.zone.now)
    pending_enrollment.reload

    expect(pending_enrollment.pending?).to eq(true)
    expect(pending_enrollment.profile.active).to eq(false)
    expect(job_analytics).to have_logged_event(
      'GetUspsProofingResultsJob: Exception raised',
      reason: reason,
      enrollment_id: pending_enrollment.id,
      enrollment_code: pending_enrollment.enrollment_code,
      exception_class: exception_class,
      exception_message: exception_message,
    )
  end

  it 'updates the status_check_attempted_at timestamp' do
    freeze_time do
      pending_enrollment.update(
        status_check_attempted_at: Time.zone.now - 1.day,
        status_updated_at: Time.zone.now - 2.days,
      )
      job.perform(Time.zone.now)

      pending_enrollment.reload
      expect(pending_enrollment.status_updated_at).to eq(Time.zone.now - 2.days)
      expect(pending_enrollment.status_check_attempted_at).to eq(Time.zone.now)
    end
  end
end

RSpec.describe GetUspsProofingResultsJob do
  include UspsIppHelper

  let(:reprocess_delay_minutes) { 2.0 }
  let(:job) { GetUspsProofingResultsJob.new }
  let(:job_analytics) { FakeAnalytics.new }

  before do
    allow(job).to receive(:analytics).and_return(job_analytics)
    allow(IdentityConfig.store).to receive(:get_usps_proofing_results_job_reprocess_delay_minutes).
      and_return(reprocess_delay_minutes)
    stub_request_token
  end

  describe '#perform' do
    describe 'IPP enabled' do
      let!(:pending_enrollments) do
        [
          create(:in_person_enrollment, :pending, selected_location_details: { name: 'BALTIMORE' }),
          create(
            :in_person_enrollment, :pending,
            selected_location_details: { name: 'FRIENDSHIP' }
          ),
          create(
            :in_person_enrollment, :pending,
            selected_location_details: { name: 'WASHINGTON' }
          ),
          create(:in_person_enrollment, :pending, selected_location_details: { name: 'ARLINGTON' }),
          create(:in_person_enrollment, :pending, selected_location_details: { name: 'DEANWOOD' }),
        ]
      end
      let(:pending_enrollment) { pending_enrollments[0] }

      before do
        allow(InPersonEnrollment).to receive(:needs_usps_status_check).
          and_return([pending_enrollment])
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      end

      it 'requests the enrollments that need their status checked' do
        stub_request_passed_proofing_results

        freeze_time do
          job.perform(Time.zone.now)

          expect(InPersonEnrollment).to(
            have_received(:needs_usps_status_check).
            with(...reprocess_delay_minutes.minutes.ago),
          )
        end
      end

      it 'records the last attempted status check regardless of response code and contents' do
        allow(InPersonEnrollment).to receive(:needs_usps_status_check).
          and_return(pending_enrollments)
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

        freeze_time do
          job.perform(Time.zone.now)

          expect(
            pending_enrollments.
              map(&:reload).
              pluck(:status_check_attempted_at),
          ).to(
            all(eq Time.zone.now),
            'job must update status check time for all pending enrollments',
          )
        end
      end

      it 'logs a message when the job starts' do
        allow(InPersonEnrollment).to receive(:needs_usps_status_check).
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
        )
      end

      it 'logs a message with counts of various outcomes when the job completes' do
        allow(InPersonEnrollment).to receive(:needs_usps_status_check).
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
          enrollments_checked: 5,
          enrollments_errored: 1,
          enrollments_expired: 1,
          enrollments_failed: 1,
          enrollments_in_progress: 1,
          enrollments_passed: 1,
        )

        expect(
          job_analytics.events['GetUspsProofingResultsJob: Job completed'].
            first[:duration],
        ).to be >= 0.0
      end

      describe 'sending emails' do
        it 'sends proofing failed email on response with failed status' do
          stub_request_failed_proofing_results

          mailer = instance_double(ActionMailer::MessageDelivery, deliver_now_or_later: true)
          user = pending_enrollment.user
          user.email_addresses.each do |email_address|
            # it sends with the default delay
            expect(mailer).to receive(:deliver_now_or_later).with(wait: 1.hour)
            expect(UserMailer).to receive(:in_person_failed).
              with(
                user,
                email_address,
                enrollment: instance_of(InPersonEnrollment),
              ).
              and_return(mailer)
          end

          job.perform(Time.zone.now)
        end

        it 'sends proofing verifed email on 2xx responses with valid JSON' do
          stub_request_passed_proofing_results

          mailer = instance_double(ActionMailer::MessageDelivery, deliver_now_or_later: true)
          user = pending_enrollment.user
          user.email_addresses.each do |email_address|
            # it sends with the default delay
            expect(mailer).to receive(:deliver_now_or_later).with(wait: 1.hour)
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

        context 'a custom delay greater than zero is set' do
          it 'uses the custom delay' do
            stub_request_passed_proofing_results

            allow(IdentityConfig.store).
              to(receive(:in_person_results_delay_in_hours).and_return(5))

            mailer = instance_double(ActionMailer::MessageDelivery, deliver_now_or_later: true)
            user = pending_enrollment.user
            user.email_addresses.each do |email_address|
              expect(mailer).to receive(:deliver_now_or_later).with(wait: 5.hours)
              expect(UserMailer).to receive(:in_person_verified).and_return(mailer)
            end

            job.perform(Time.zone.now)
          end
        end

        context 'a custom delay of zero is set' do
          it 'does not delay sending the email' do
            stub_request_passed_proofing_results

            allow(IdentityConfig.store).
              to(receive(:in_person_results_delay_in_hours).and_return(0))

            mailer = instance_double(ActionMailer::MessageDelivery, deliver_now_or_later: true)
            user = pending_enrollment.user
            user.email_addresses.each do |email_address|
              expect(mailer).to receive(:deliver_now_or_later).with(no_args)
              expect(UserMailer).to receive(:in_person_verified).and_return(mailer)
            end

            job.perform(Time.zone.now)
          end
        end
      end

      context 'when an enrollment passes' do
        before(:each) do
          stub_request_passed_proofing_results
        end

        it_behaves_like('enrollment with a status update', passed: true, status: 'passed')

        it 'logs details about the success' do
          job.perform(Time.zone.now)

          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Enrollment status updated',
            fraud_suspected: false,
            reason: 'Successful status update',
          )
        end
      end

      context 'when an enrollment fails' do
        before(:each) do
          stub_request_failed_proofing_results
        end

        it_behaves_like('enrollment with a status update', passed: false, status: 'failed')

        it 'logs failure details' do
          job.perform(Time.zone.now)

          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Enrollment status updated',
            failure_reason: 'Clerk indicates that ID name or address does not match source data.',
            fraud_suspected: false,
            primary_id_type: 'Uniformed Services identification card',
            proofing_state: 'PA',
            reason: 'Failed status',
            secondary_id_type: 'Deed of Trust',
            transaction_end_date_time: '12/17/2020 034055',
            transaction_start_date_time: '12/17/2020 033855',
          )
        end
      end

      context 'when an enrollment passes proofing with an unsupported ID' do
        before(:each) do
          stub_request_passed_proofing_unsupported_id_results
        end

        it_behaves_like('enrollment with a status update', passed: false, status: 'failed')

        it 'logs a message about the unsupported ID' do
          job.perform Time.zone.now

          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Enrollment status updated',
            fraud_suspected: false,
            primary_id_type: 'Not supported',
            reason: 'Unsupported ID type',
          )
        end
      end

      context 'when an enrollment expires' do
        before(:each) do
          stub_request_expired_proofing_results
        end

        it_behaves_like('enrollment with a status update', passed: false, status: 'expired')

        it 'logs that the enrollment expired' do
          job.perform(Time.zone.now)

          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Enrollment status updated',
            reason: 'Enrollment has expired',
          )
        end
      end

      context 'when USPS returns a non-hash response' do
        before(:each) do
          stub_request_proofing_results_with_responses({})
        end

        it_behaves_like('enrollment encountering an exception', reason: 'Bad response structure')
      end

      context 'when USPS returns an unexpected status' do
        before(:each) do
          stub_request_passed_proofing_unsupported_status_results
        end

        it_behaves_like('enrollment encountering an exception', reason: 'Unsupported status')

        it 'logs the status received' do
          job.perform(Time.zone.now)
          pending_enrollment.reload

          expect(pending_enrollment.pending?).to be_truthy
          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Exception raised',
            status: 'Not supported',
          )
        end
      end

      context 'when USPS returns invalid JSON' do
        before(:each) do
          stub_request_proofing_results_with_invalid_response
        end

        it_behaves_like(
          'enrollment encountering an exception',
          exception_class: 'Faraday::ParsingError',
          exception_message: "809: unexpected token at 'invalid'",
        )
      end

      context 'when USPS returns a 4xx status code' do
        before(:each) do
          stub_request_proofing_results_with_responses({ status: 400 })
        end

        it_behaves_like(
          'enrollment encountering an exception',
          exception_class: 'Faraday::BadRequestError',
          exception_message: 'the server responded with status 400',
        )
      end

      context 'when USPS returns a 5xx status code' do
        before(:each) do
          stub_request_proofing_results_with_responses({ status: 500 })
        end

        it_behaves_like(
          'enrollment encountering an exception',
          exception_class: 'Faraday::ServerError',
          exception_message: 'the server responded with status 500',
        )
      end

      context 'when there is no status update' do
        before(:each) do
          stub_request_in_progress_proofing_results
        end

        it 'updates the timestamp but does not update the status or log a message' do
          freeze_time do
            pending_enrollment.update(
              status_check_attempted_at: Time.zone.now - 1.day,
              status_updated_at: Time.zone.now - 1.day,
            )
            job.perform(Time.zone.now)

            pending_enrollment.reload
            expect(pending_enrollment.status_updated_at).to eq(Time.zone.now - 1.day)
            expect(pending_enrollment.status_check_attempted_at).to eq(Time.zone.now)
          end

          expect(pending_enrollment.profile.active).to eq(false)
          expect(pending_enrollment.pending?).to be_truthy

          expect(job_analytics).not_to have_logged_event(
            'GetUspsProofingResultsJob: Enrollment status updated',
          )
        end
      end
    end

    describe 'IPP disabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(false)
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
