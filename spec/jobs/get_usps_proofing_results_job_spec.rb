require 'rails_helper'

RSpec.shared_examples 'enrollment_with_a_status_update' do |passed:, status:, response_json:|
  it 'logs a message with common attributes' do
    freeze_time do
      pending_enrollment.update(
        enrollment_established_at: Time.zone.now - 3.days,
        status_check_attempted_at: Time.zone.now - 15.minutes,
        status_updated_at: Time.zone.now - 2.days,
      )

      job.perform(Time.zone.now)
    end

    response = JSON.parse(response_json)
    expect(job_analytics).to have_logged_event(
      'GetUspsProofingResultsJob: Enrollment status updated',
      assurance_level: response['assuranceLevel'],
      enrollment_code: pending_enrollment.enrollment_code,
      enrollment_id: pending_enrollment.id,
      failure_reason: response['failureReason'],
      fraud_suspected: response['fraudSuspected'],
      issuer: pending_enrollment.issuer,
      minutes_since_last_status_check: 15.0,
      minutes_since_last_status_update: 2.days.in_minutes,
      minutes_to_completion: 3.days.in_minutes,
      passed: passed,
      primary_id_type: response['primaryIdType'],
      proofing_city: response['proofingCity'],
      proofing_post_office: response['proofingPostOffice'],
      proofing_state: response['proofingState'],
      response_message: response['responseMessage'],
      scan_count: response['scanCount'],
      secondary_id_type: response['secondaryIdType'],
      status: response['status'],
      transaction_end_date_time: response['transactionEndDateTime'],
      transaction_start_date_time: response['transactionStartDateTime'],
    )
  end

  context 'email_analytics_attributes' do
    before(:each) do
      stub_request_passed_proofing_results
    end
    it 'logs message with email analytics attributes' do
      freeze_time do
        job.perform(Time.zone.now)
        expect(job_analytics).to have_logged_event(
          'GetUspsProofingResultsJob: Success or failure email initiated',
          delay_time_seconds: 3600,
          service_provider: pending_enrollment.issuer,
          timestamp: Time.zone.now,
          user_id: pending_enrollment.user_id,
        )
      end
    end
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

RSpec.shared_examples 'enrollment_encountering_an_exception' do |exception_class: nil,
                                                                exception_message: nil,
                                                                reason: 'Request exception',
                                                                response_message: nil,
                                                                response_status_code: nil|
  it 'logs an error message and leaves the enrollment and profile pending' do
    job.perform(Time.zone.now)
    pending_enrollment.reload

    expect(pending_enrollment.pending?).to eq(true)
    expect(pending_enrollment.profile.active).to eq(false)
    expect(job_analytics).to have_logged_event(
      'GetUspsProofingResultsJob: Exception raised',
      include(
        enrollment_code: pending_enrollment.enrollment_code,
        enrollment_id: pending_enrollment.id,
        exception_class: exception_class,
        exception_message: exception_message,
        reason: reason,
        response_message: response_message,
        response_status_code: response_status_code,
      ),
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

RSpec.shared_examples 'enrollment_encountering_an_error_that_has_a_nil_response' do |error_type:|
  it 'logs that response is not present' do
    expect(NewRelic::Agent).to receive(:notice_error).with(instance_of(error_type))

    job.perform(Time.zone.now)

    expect(job_analytics).to have_logged_event(
      'GetUspsProofingResultsJob: Exception raised',
      response_present: false,
      exception_class: error_type.to_s,
    )
  end
end

RSpec.describe GetUspsProofingResultsJob do
  include UspsIppHelper

  let(:reprocess_delay_minutes) { 2.0 }
  let(:request_delay_ms) { 0 }
  let(:job) { GetUspsProofingResultsJob.new }
  let(:job_analytics) { FakeAnalytics.new }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(job).to receive(:analytics).and_return(job_analytics)
    allow(IdentityConfig.store).to receive(:get_usps_proofing_results_job_reprocess_delay_minutes).
      and_return(reprocess_delay_minutes)
    allow(IdentityConfig.store).
      to receive(:get_usps_proofing_results_job_request_delay_milliseconds).
      and_return(request_delay_ms)
    stub_request_token
  end

  describe '#perform' do
    describe 'IPP enabled' do
      let!(:pending_enrollments) do
        [
          create(
            :in_person_enrollment, :pending,
            selected_location_details: { name: 'BALTIMORE' },
            issuer: 'http://localhost:3000'
          ),
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
            first[:duration_seconds],
        ).to be >= 0.0
      end

      context 'a standard error is raised when requesting proofing results' do
        let(:error_message) { 'A standard error happened' }
        let!(:error) { StandardError.new(error_message) }
        let!(:proofer) { described_class.new }

        it 'logs failure details' do
          allow(UspsInPersonProofing::Proofer).to receive(:new).and_return(proofer)
          allow(proofer).to receive(:request_proofing_results).and_raise(error)
          expect(NewRelic::Agent).to receive(:notice_error).with(error)

          job.perform(Time.zone.now)

          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Exception raised',
            exception_message: error_message,
          )
        end
      end

      context 'with a request delay in ms' do
        let(:request_delay_ms) { 750 }

        it 'adds a delay between requests to USPS' do
          allow(InPersonEnrollment).to receive(:needs_usps_status_check).
            and_return(pending_enrollments)
          stub_request_passed_proofing_results
          expect(job).to receive(:sleep).exactly(pending_enrollments.length - 1).times.
            with(0.75)

          job.perform(Time.zone.now)
        end
      end

      context 'when an enrollment does not have a unique ID' do
        it 'generates a backwards-compatible unique ID' do
          pending_enrollment.update(unique_id: nil)
          stub_request_passed_proofing_results
          expect(pending_enrollment).to receive(:usps_unique_id).and_call_original

          job.perform(Time.zone.now)

          expect(pending_enrollment.unique_id).not_to be_nil
        end
      end

      describe 'sending emails' do
        it 'sends proofing failed email on response with failed status' do
          stub_request_failed_proofing_results

          user = pending_enrollment.user

          freeze_time do
            expect do
              job.perform(Time.zone.now)
            end.to have_enqueued_mail(UserMailer, :in_person_failed).with(
              params: { user: user, email_address: user.email_addresses.first },
              args: [{ enrollment: pending_enrollment }],
            ).at(Time.zone.now + 1.hour)
          end
        end

        it 'sends failed email when fraudSuspected is true' do
          stub_request_failed_suspected_fraud_proofing_results

          user = pending_enrollment.user

          freeze_time do
            expect do
              job.perform(Time.zone.now)
            end.to have_enqueued_mail(UserMailer, :in_person_failed_fraud).with(
              params: { user: user, email_address: user.email_addresses.first },
              args: [{ enrollment: pending_enrollment }],
            ).at(Time.zone.now + 1.hour)
          end
        end

        it 'sends proofing verifed email on 2xx responses with valid JSON' do
          stub_request_passed_proofing_results

          user = pending_enrollment.user

          freeze_time do
            expect do
              job.perform(Time.zone.now)
            end.to have_enqueued_mail(UserMailer, :in_person_verified).with(
              params: { user: user, email_address: user.email_addresses.first },
              args: [{ enrollment: pending_enrollment }],
            ).at(Time.zone.now + 1.hour)
          end
        end

        context 'a custom delay greater than zero is set' do
          it 'uses the custom delay' do
            stub_request_passed_proofing_results

            allow(IdentityConfig.store).
              to(receive(:in_person_results_delay_in_hours).and_return(5))
            user = pending_enrollment.user

            freeze_time do
              expect do
                job.perform(Time.zone.now)
              end.to have_enqueued_mail(UserMailer, :in_person_verified).with(
                params: { user: user, email_address: user.email_addresses.first },
                args: [{ enrollment: pending_enrollment }],
              ).at(Time.zone.now + 5.hours)
            end
          end
        end

        context 'a custom delay of zero is set' do
          it 'does not delay sending the email' do
            stub_request_passed_proofing_results

            allow(IdentityConfig.store).
              to(receive(:in_person_results_delay_in_hours).and_return(0))
            user = pending_enrollment.user

            freeze_time do
              expect do
                job.perform(Time.zone.now)
              end.to have_enqueued_mail(UserMailer, :in_person_verified).with(
                params: { user: user, email_address: user.email_addresses.first },
                args: [{ enrollment: pending_enrollment }],
              )
            end
          end
        end
      end

      context 'when an enrollment passes' do
        before(:each) do
          stub_request_passed_proofing_results
        end

        it_behaves_like(
          'enrollment_with_a_status_update',
          passed: true,
          status: 'passed',
          response_json: UspsInPersonProofing::Mock::Fixtures.
            request_passed_proofing_results_response,
        )

        it 'logs details about the success' do
          job.perform(Time.zone.now)

          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Enrollment status updated',
            reason: 'Successful status update',
          )
          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Success or failure email initiated',
            email_type: 'Success',
          )
        end
      end

      context 'when an enrollment fails' do
        before(:each) do
          stub_request_failed_proofing_results
        end

        it_behaves_like(
          'enrollment_with_a_status_update',
          passed: false,
          status: 'failed',
          response_json: UspsInPersonProofing::Mock::Fixtures.
            request_failed_proofing_results_response,
        )

        it 'logs failure details' do
          job.perform(Time.zone.now)

          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Enrollment status updated',
          )
          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Success or failure email initiated',
            email_type: 'Failed',
          )
        end
      end

      context 'when an enrollment fails and fraud is suspected' do
        before(:each) do
          stub_request_failed_suspected_fraud_proofing_results
        end

        it_behaves_like(
          'enrollment_with_a_status_update',
          passed: false,
          status: 'failed',
          response_json: UspsInPersonProofing::Mock::Fixtures.
            request_failed_suspected_fraud_proofing_results_response,
        )

        it 'logs fraud failure details' do
          job.perform(Time.zone.now)

          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Enrollment status updated',
          )
          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Success or failure email initiated',
            email_type: 'Failed fraud suspected',
          )
        end
      end

      context 'when an enrollment passes proofing with an unsupported ID' do
        before(:each) do
          stub_request_passed_proofing_unsupported_id_results
        end

        it_behaves_like(
          'enrollment_with_a_status_update',
          passed: false,
          status: 'failed',
          response_json: UspsInPersonProofing::Mock::Fixtures.
            request_passed_proofing_unsupported_id_results_response,
        )

        it 'logs a message about the unsupported ID' do
          job.perform Time.zone.now

          expect(job_analytics).to have_logged_event(
            'GetUspsProofingResultsJob: Enrollment status updated',
            reason: 'Unsupported ID type',
          )
        end
      end

      context 'when an enrollment expires' do
        before(:each) do
          stub_request_expired_proofing_results
        end

        it_behaves_like(
          'enrollment_with_a_status_update',
          passed: false,
          status: 'expired',
          response_json: UspsInPersonProofing::Mock::Fixtures.
            request_expired_proofing_results_response,
        )

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

        it_behaves_like(
          'enrollment_encountering_an_exception',
          reason: 'Bad response structure',
        )
      end

      context 'when USPS returns an unexpected status' do
        before(:each) do
          stub_request_passed_proofing_unsupported_status_results
        end

        it_behaves_like(
          'enrollment_encountering_an_exception',
          reason: 'Unsupported status',
        )

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
          'enrollment_encountering_an_exception',
          reason: 'Bad response structure',
        )
      end

      context 'when USPS returns a 4xx status code' do
        before(:each) do
          stub_request_proofing_results_with_responses(
            {
              status: 410,
              body: { 'responseMessage' => 'Applicant does not exist' }.to_json,
              headers: { 'content-type': 'application/json' },
            },
          )
        end

        it_behaves_like(
          'enrollment_encountering_an_exception',
          exception_class: 'Faraday::ClientError',
          exception_message: 'the server responded with status 410',
          response_message: 'Applicant does not exist',
          response_status_code: 410,
        )

        it 'logs the error to NewRelic' do
          expect(NewRelic::Agent).to receive(:notice_error).with(instance_of(Faraday::ClientError))
          job.perform(Time.zone.now)
        end
      end

      context 'when USPS returns a 5xx status code' do
        before(:each) do
          stub_request_proofing_results_internal_server_error
        end

        it_behaves_like(
          'enrollment_encountering_an_exception',
          exception_class: 'Faraday::ServerError',
          exception_message: 'the server responded with status 500',
          response_message: 'An internal error occurred processing the request',
          response_status_code: 500,
        )

        it 'logs the error to NewRelic' do
          expect(NewRelic::Agent).to receive(:notice_error).with(instance_of(Faraday::ServerError))
          job.perform(Time.zone.now)
        end
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

      context 'when a timeout error occurs' do
        before(:each) do
          stub_request_proofing_results_with_timeout_error
        end

        it_behaves_like(
          'enrollment_encountering_an_error_that_has_a_nil_response',
          error_type: Faraday::TimeoutError,
        )
      end

      context 'when a nil status error occurs' do
        before(:each) do
          stub_request_proofing_results_with_nil_status_error
        end

        it_behaves_like(
          'enrollment_encountering_an_error_that_has_a_nil_response',
          error_type: Faraday::NilStatusError,
        )
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
