require 'rails_helper'

RSpec.describe GetUspsProofingResultsJob, freeze_time: true do
  include UspsIppHelper

  let(:current_time) { Time.zone.now }
  let(:in_person_results_delay_in_hours) { 2 }
  let(:analytics) do
    instance_double(Analytics)
  end
  let(:default_job_completion_analytics) do
    {
      enrollments_checked: 0,
      enrollments_errored: 0,
      enrollments_network_error: 0,
      enrollments_expired: 0,
      enrollments_failed: 0,
      enrollments_cancelled: 0,
      enrollments_in_progress: 0,
      enrollments_passed: 0,
      enrollments_skipped: 0,
      duration_seconds: 0.0,
      percent_enrollments_errored: 0.0,
      percent_enrollments_network_error: 0.0,
      job_name: described_class.name,
    }
  end

  before do
    travel_to(current_time)
    allow(analytics).to receive(:idv_in_person_usps_proofing_results_job_started)
    allow(analytics).to receive(:idv_in_person_usps_proofing_results_job_completed)
    allow(Analytics).to receive(:new).and_return(analytics)
    allow(IdentityConfig.store).to receive(:usps_mock_fallback).and_return(false)
    allow(IdentityConfig.store).to receive(:in_person_results_delay_in_hours).and_return(
      in_person_results_delay_in_hours,
    )
    allow(NewRelic::Agent).to receive(:notice_error)
    stub_request_token
  end

  describe '#perform' do
    describe 'when the job is disabled' do
      context 'when the in person enrollments ready job is enabled' do
        before do
          allow(IdentityConfig.store).to receive(
            :in_person_enrollments_ready_job_enabled,
          ).and_return(true)
        end

        context 'when in person proofing is enabled' do
          before do
            allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
            subject.perform(current_time)
          end

          it 'does not log the job started analytic' do
            expect(analytics).not_to have_received(:idv_in_person_usps_proofing_results_job_started)
          end
        end

        context 'when in person proofing is disabled' do
          before do
            allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(false)
            subject.perform(current_time)
          end

          it 'does not log the job started analytic' do
            expect(analytics).not_to have_received(:idv_in_person_usps_proofing_results_job_started)
          end
        end
      end

      context 'when the in person enrollments ready job is disabled' do
        before do
          allow(IdentityConfig.store).to receive(
            :in_person_enrollments_ready_job_enabled,
          ).and_return(false)
        end

        context 'when in person proofing is disabled' do
          before do
            allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(false)
            subject.perform(current_time)
          end

          it 'does not log the job started analytic' do
            expect(analytics).not_to have_received(:idv_in_person_usps_proofing_results_job_started)
          end
        end
      end
    end

    describe 'when the job is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
        allow(IdentityConfig.store).to receive(
          :in_person_enrollments_ready_job_enabled,
        ).and_return(false)
      end

      context 'when pending InPersonEnrollments exist' do
        let(:user_mailer) { double(UserMailer) }
        let(:mail_deliverer) { double(ActionMailer::MessageDelivery) }
        let(:send_proofing_notification_job) do
          double(InPerson::SendProofingNotificationJob)
        end
        let(:no_visited_location_name) { 'none' }
        let(:visited_location_name) { 'WILKES BARRE' }
        let(:enrollment) do
          create(:in_person_enrollment, :pending, :with_notification_phone_configuration)
        end
        let(:enrollment_analytics) do
          {
            enrollment_code: enrollment.enrollment_code,
            enrollment_id: enrollment.id,
            minutes_since_last_status_check: enrollment.minutes_since_last_status_check,
            minutes_since_last_status_check_completed:
              enrollment.minutes_since_last_status_check_completed,
            minutes_since_last_status_update:
              enrollment.minutes_since_last_status_update,
            minutes_since_established: enrollment.minutes_since_established,
            minutes_to_completion: enrollment.minutes_since_established,
            issuer: enrollment.issuer,
          }
        end

        before do
          allow(InPersonEnrollment).to receive(:needs_usps_status_check).and_return(
            InPersonEnrollment.where(id: enrollment.id),
          )
          allow(UserMailer).to receive(:with).with(
            user: enrollment.user,
            email_address: enrollment.user.last_sign_in_email_address,
          ).and_return(user_mailer)
          allow(mail_deliverer).to receive(:deliver_later)
          allow(InPerson::SendProofingNotificationJob).to receive(:set).and_return(
            send_proofing_notification_job,
          )
          allow(send_proofing_notification_job).to receive(:perform_later)
        end

        context 'when the USPS client request proofing results throws an exception' do
          let(:response_analytics) do
            {
              fraud_suspected: nil,
              primary_id_type: nil,
              secondary_id_type: nil,
              failure_reason: nil,
              transaction_end_date_time: nil,
              transaction_start_date_time: nil,
              status: nil,
              assurance_level: nil,
              proofing_post_office: nil,
              proofing_city: nil,
              proofing_state: nil,
              scan_count: nil,
              response_present: true,
            }
          end

          context 'when the exception is a Faraday::BadRequestError' do
            context 'when the exception response message is an IPP_INCOMPLETE_ERROR' do
              before do
                stub_request_in_progress_proofing_results
                allow(analytics).to receive(
                  :idv_in_person_usps_proofing_results_job_enrollment_incomplete,
                )
                subject.perform(current_time)
              end

              it 'logs the job started analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_started,
                ).with(
                  enrollments_count: 1,
                  reprocess_delay_minutes: 5,
                  job_name: described_class.name,
                )
              end

              it 'logs the job enrollment incomplete analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_enrollment_incomplete,
                ).with(
                  **enrollment_analytics,
                  minutes_to_completion: nil,
                  response_message: 'Customer has not been to a post office to complete IPP',
                  job_name: described_class.name,
                )
              end

              it 'updates the enrollment status check timestamps' do
                expect(enrollment.reload).to have_attributes(
                  status_check_attempted_at: current_time,
                  status_check_completed_at: current_time,
                  last_batch_claimed_at: current_time,
                )
              end

              it 'logs the job completed analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_completed,
                ).with(
                  **default_job_completion_analytics,
                  enrollments_checked: 1,
                  enrollments_in_progress: 1,
                )
              end
            end

            context 'when the exception response message is IPP_EXPIRED_ERROR' do
              before do
                stub_request_expired_id_ipp_proofing_results
              end

              context 'when in person proofing is configured to not expire enrollments' do
                before do
                  allow(IdentityConfig.store).to receive(
                    :in_person_stop_expiring_enrollments,
                  ).and_return(true)
                  allow(analytics).to receive(
                    :idv_in_person_usps_proofing_results_job_enrollment_incomplete,
                  )
                  subject.perform(current_time)
                end

                it 'logs the job started analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_started,
                  ).with(
                    enrollments_count: 1,
                    reprocess_delay_minutes: 5,
                    job_name: described_class.name,
                  )
                end

                it 'logs the job enrollment incomplete analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_enrollment_incomplete,
                  ).with(
                    **enrollment_analytics,
                    minutes_to_completion: nil,
                    response_message: 'More than 30 days have passed since opt-in to IPP',
                    job_name: described_class.name,
                  )
                end

                it 'updates the enrollment status check timestamps' do
                  expect(enrollment.reload).to have_attributes(
                    status_check_attempted_at: current_time,
                    status_check_completed_at: current_time,
                    last_batch_claimed_at: current_time,
                  )
                end

                it 'logs the job completed analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_completed,
                  ).with(
                    **default_job_completion_analytics,
                    enrollments_checked: 1,
                    enrollments_in_progress: 1,
                  )
                end
              end

              context 'when in person proofing is configured to expire enrollments' do
                context 'when the enrollment does not have fraud results pending' do
                  context 'when the deadline email does not throw an exception' do
                    before do
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      )
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated,
                      )
                      allow(user_mailer).to receive(:in_person_deadline_passed).and_return(
                        mail_deliverer,
                      )
                      subject.perform(current_time)
                    end

                    it 'logs the job started analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_started,
                      ).with(
                        enrollments_count: 1,
                        reprocess_delay_minutes: 5,
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job enrollment updated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      ).with(
                        **enrollment_analytics,
                        **response_analytics,
                        response_message: 'More than 30 days have passed since opt-in to IPP',
                        passed: false,
                        reason: 'Enrollment has expired',
                        job_name: described_class.name,
                        tmx_status: enrollment.profile&.tmx_status,
                        profile_age_in_seconds: instance_of(Integer),
                        enhanced_ipp: enrollment.enhanced_ipp?,
                      )
                    end

                    it 'expires the enrollment' do
                      expect(enrollment.reload).to have_attributes(
                        status: 'expired',
                        status_check_attempted_at: current_time,
                        status_check_completed_at: current_time,
                        last_batch_claimed_at: current_time,
                        deadline_passed_sent: true,
                      )
                    end

                    it "deactivates the enrollment's profile" do
                      expect(enrollment.reload.profile).to have_attributes(
                        active: false,
                        deactivation_reason: 'verification_cancelled',
                        in_person_verification_pending_at: nil,
                      )
                    end

                    it 'sends an in person deadline passed email' do
                      expect(user_mailer).to have_received(:in_person_deadline_passed).with(
                        enrollment: enrollment,
                        visited_location_name: no_visited_location_name,
                      )
                      expect(mail_deliverer).to have_received(:deliver_later).with(no_args)
                    end

                    it 'logs the job deadline passed email initiated' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated,
                      ).with(
                        enrollment_code: enrollment.enrollment_code,
                        timestamp: current_time,
                        service_provider: enrollment.issuer,
                        wait_until: nil,
                        enrollment_id: enrollment.id,
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job completed analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_completed,
                      ).with(
                        **default_job_completion_analytics,
                        enrollments_checked: 1,
                        enrollments_expired: 1,
                      )
                    end
                  end

                  context 'when the deadline email throws an exception' do
                    before do
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      )
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_deadline_passed_email_exception,
                      )
                      allow(UserMailer).to receive(:with).with(
                        user: enrollment.user,
                        email_address: enrollment.user.last_sign_in_email_address,
                      ).and_raise(StandardError)
                      subject.perform(current_time)
                    end

                    it 'logs the job started analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_started,
                      ).with(
                        enrollments_count: 1,
                        reprocess_delay_minutes: 5,
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job enrollment updated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      ).with(
                        **enrollment_analytics,
                        **response_analytics,
                        response_message: 'More than 30 days have passed since opt-in to IPP',
                        passed: false,
                        reason: 'Enrollment has expired',
                        job_name: described_class.name,
                        tmx_status: enrollment.profile&.tmx_status,
                        profile_age_in_seconds: instance_of(Integer),
                        enhanced_ipp: enrollment.enhanced_ipp?,
                      )
                    end

                    it 'expires the enrollment' do
                      expect(enrollment.reload).to have_attributes(
                        status: 'expired',
                        status_check_attempted_at: current_time,
                        status_check_completed_at: current_time,
                        last_batch_claimed_at: current_time,
                      )
                    end

                    it "deactivates the enrollment's profile" do
                      expect(enrollment.reload.profile).to have_attributes(
                        active: false,
                        deactivation_reason: 'verification_cancelled',
                        in_person_verification_pending_at: nil,
                      )
                    end

                    it 'notifies new relic with the error' do
                      expect(NewRelic::Agent).to have_received(:notice_error).with(
                        instance_of(StandardError),
                      )
                    end

                    it 'logs the job deadline passed email exception' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_deadline_passed_email_exception,
                      ).with(
                        enrollment_id: enrollment.id,
                        exception_class: 'StandardError',
                        exception_message: 'StandardError',
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job completed analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_completed,
                      ).with(
                        **default_job_completion_analytics,
                        enrollments_checked: 1,
                        enrollments_expired: 1,
                      )
                    end
                  end

                  context 'when in person enrollment validity in days does not match response' do
                    before do
                      allow(IdentityConfig.store).to receive(
                        :in_person_enrollment_validity_in_days,
                      ).and_return(7)
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      )
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated,
                      )
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_unexpected_response,
                      )
                      allow(user_mailer).to receive(:in_person_deadline_passed).and_return(
                        mail_deliverer,
                      )
                      subject.perform(current_time)
                    end

                    it 'logs the job started analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_started,
                      ).with(
                        enrollments_count: 1,
                        reprocess_delay_minutes: 5,
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job enrollment updated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      ).with(
                        **enrollment_analytics,
                        **response_analytics,
                        response_message: 'More than 30 days have passed since opt-in to IPP',
                        passed: false,
                        reason: 'Enrollment has expired',
                        job_name: described_class.name,
                        tmx_status: enrollment.profile&.tmx_status,
                        profile_age_in_seconds: instance_of(Integer),
                        enhanced_ipp: enrollment.enhanced_ipp?,
                      )
                    end

                    it 'expires the enrollment' do
                      expect(enrollment.reload).to have_attributes(
                        status: 'expired',
                        status_check_attempted_at: current_time,
                        status_check_completed_at: current_time,
                        last_batch_claimed_at: current_time,
                      )
                    end

                    it 'sends an in person deadline passed email' do
                      expect(user_mailer).to have_received(:in_person_deadline_passed).with(
                        enrollment: enrollment,
                        visited_location_name: no_visited_location_name,
                      )
                      expect(mail_deliverer).to have_received(:deliver_later).with(no_args)
                    end

                    it 'logs the job deadline passed email initiated' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated,
                      ).with(
                        enrollment_code: enrollment.enrollment_code,
                        timestamp: current_time,
                        service_provider: enrollment.issuer,
                        wait_until: nil,
                        enrollment_id: enrollment.id,
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job unexpected response analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_unexpected_response,
                      ).with(
                        **enrollment_analytics,
                        minutes_to_completion: nil,
                        minutes_since_last_status_check_completed: 0.0,
                        response_message: 'More than 30 days have passed since opt-in to IPP',
                        reason: 'Unexpected number of days before enrollment expired',
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job completed analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_completed,
                      ).with(
                        **default_job_completion_analytics,
                        enrollments_checked: 1,
                        enrollments_expired: 1,
                      )
                    end
                  end

                  context 'when the deadline email has already been sent for the enrollment' do
                    before do
                      enrollment.update(deadline_passed_sent: true)
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      )
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated,
                      )
                      allow(user_mailer).to receive(:in_person_deadline_passed)
                      subject.perform(current_time)
                    end

                    it 'logs the job started analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_started,
                      ).with(
                        enrollments_count: 1,
                        reprocess_delay_minutes: 5,
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job enrollment updated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      ).with(
                        **enrollment_analytics,
                        **response_analytics,
                        response_message: 'More than 30 days have passed since opt-in to IPP',
                        passed: false,
                        reason: 'Enrollment has expired',
                        job_name: described_class.name,
                        tmx_status: enrollment.profile&.tmx_status,
                        profile_age_in_seconds: instance_of(Integer),
                        enhanced_ipp: enrollment.enhanced_ipp?,
                      )
                    end

                    it 'expires the enrollment' do
                      expect(enrollment.reload).to have_attributes(
                        status: 'expired',
                        status_check_attempted_at: current_time,
                        status_check_completed_at: current_time,
                        last_batch_claimed_at: current_time,
                      )
                    end

                    it 'does not send an in person deadline passed email' do
                      expect(user_mailer).not_to have_received(:in_person_deadline_passed)
                    end

                    it 'logs the job deadline passed email initiated' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated,
                      ).with(
                        enrollment_code: enrollment.enrollment_code,
                        timestamp: current_time,
                        service_provider: enrollment.issuer,
                        wait_until: nil,
                        enrollment_id: enrollment.id,
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job completed analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_completed,
                      ).with(
                        **default_job_completion_analytics,
                        enrollments_checked: 1,
                        enrollments_expired: 1,
                      )
                    end
                  end
                end

                context 'when the enrollment has fraud results pending' do
                  before do
                    allow(IdentityConfig.store).to receive(
                      :in_person_proofing_enforce_tmx,
                    ).and_return(true)
                    enrollment.profile.update(
                      fraud_pending_reason: 'threatmetrix_review',
                      proofing_components: { threatmetrix_review_status: 'review' },
                    )
                    allow(analytics).to receive(
                      :idv_in_person_usps_proofing_results_job_enrollment_updated,
                    )
                    allow(analytics).to receive(
                      :idv_ipp_deactivated_for_never_visiting_post_office,
                    )
                    allow(analytics).to receive(
                      :idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated,
                    )
                    allow(user_mailer).to receive(:in_person_deadline_passed).and_return(
                      mail_deliverer,
                    )
                    subject.perform(current_time)
                  end

                  it 'logs the job started analytic' do
                    expect(analytics).to have_received(
                      :idv_in_person_usps_proofing_results_job_started,
                    ).with(
                      enrollments_count: 1,
                      reprocess_delay_minutes: 5,
                      job_name: described_class.name,
                    )
                  end

                  it 'logs the job enrollment updated analytic' do
                    expect(analytics).to have_received(
                      :idv_in_person_usps_proofing_results_job_enrollment_updated,
                    ).with(
                      **enrollment_analytics,
                      **response_analytics,
                      response_message: 'More than 30 days have passed since opt-in to IPP',
                      passed: false,
                      reason: 'Enrollment has expired',
                      job_name: described_class.name,
                      tmx_status: enrollment.profile&.tmx_status,
                      profile_age_in_seconds: instance_of(Integer),
                      enhanced_ipp: enrollment.enhanced_ipp?,
                    )
                  end

                  it 'expires the enrollment' do
                    expect(enrollment.reload).to have_attributes(
                      status: 'expired',
                      status_check_attempted_at: current_time,
                      status_check_completed_at: current_time,
                      last_batch_claimed_at: current_time,
                    )
                  end

                  it "deactivates the enrollment's profile" do
                    expect(enrollment.reload.profile).to have_attributes(
                      active: false,
                      deactivation_reason: 'verification_cancelled',
                      in_person_verification_pending_at: nil,
                      fraud_rejection_at: current_time,
                    )
                  end

                  it 'logs the idv ipp deactivated for never visiting the post office analytic' do
                    expect(analytics).to have_received(
                      :idv_ipp_deactivated_for_never_visiting_post_office,
                    ).with(
                      **enrollment_analytics,
                      minutes_since_last_status_check_completed: 0.0,
                    )
                  end

                  it 'sends an in person deadline passed email' do
                    expect(user_mailer).to have_received(:in_person_deadline_passed).with(
                      enrollment: enrollment,
                      visited_location_name: no_visited_location_name,
                    )
                    expect(mail_deliverer).to have_received(:deliver_later).with(no_args)
                  end

                  it 'logs the job completed analytic' do
                    expect(analytics).to have_received(
                      :idv_in_person_usps_proofing_results_job_completed,
                    ).with(
                      **default_job_completion_analytics,
                      enrollments_checked: 1,
                      enrollments_expired: 1,
                    )
                  end
                end
              end
            end

            context 'when the exception response message is IPP_INVALID_ENROLLMENT_CODE' do
              let(:response_message) do
                "Enrollment code #{enrollment.enrollment_code} does not exist"
              end

              before do
                stub_request_unexpected_invalid_enrollment_code(
                  { 'responseMessage' => response_message },
                )
                allow(analytics).to receive(
                  :idv_in_person_usps_proofing_results_job_enrollment_updated,
                )
                allow(analytics).to receive(
                  :idv_in_person_usps_proofing_results_job_unexpected_response,
                )
                subject.perform(current_time)
              end

              it 'logs the job started analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_started,
                ).with(
                  enrollments_count: 1,
                  reprocess_delay_minutes: 5,
                  job_name: described_class.name,
                )
              end

              it 'logs the job enrollment updated analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_enrollment_updated,
                ).with(
                  **enrollment_analytics,
                  minutes_to_completion: nil,
                  **response_analytics,
                  response_message: response_message,
                  passed: false,
                  reason: 'Invalid enrollment code',
                  job_name: described_class.name,
                  tmx_status: enrollment.profile&.tmx_status,
                  profile_age_in_seconds: instance_of(Integer),
                  enhanced_ipp: enrollment.enhanced_ipp?,
                )
              end

              it 'cancels the enrollment' do
                expect(enrollment.reload).to have_attributes(
                  status_check_attempted_at: current_time,
                  last_batch_claimed_at: current_time,
                  status: 'cancelled',
                )
              end

              it "deactivates the enrollment's profile" do
                expect(enrollment.reload.profile).to have_attributes(
                  active: false,
                  deactivation_reason: 'verification_cancelled',
                  in_person_verification_pending_at: nil,
                )
              end

              it 'logs the job unexpected response analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_unexpected_response,
                ).with(
                  **enrollment_analytics,
                  response_message: "Enrollment code #{enrollment.enrollment_code} does not exist",
                  reason: 'Invalid enrollment code',
                  job_name: described_class.name,
                )
              end

              it 'logs the job completed analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_completed,
                ).with(
                  **default_job_completion_analytics,
                  enrollments_checked: 1,
                  enrollments_cancelled: 1,
                )
              end
            end

            context 'when the exception response message is IPP_INVALID_APPLICANT' do
              let(:response_message) { "Applicant #{enrollment.unique_id} does not exist" }

              before do
                stub_request_unexpected_invalid_applicant({ 'responseMessage' => response_message })
                allow(analytics).to receive(
                  :idv_in_person_usps_proofing_results_job_enrollment_updated,
                )
                allow(analytics).to receive(
                  :idv_in_person_usps_proofing_results_job_unexpected_response,
                )
                subject.perform(current_time)
              end

              it 'logs the job started analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_started,
                ).with(
                  enrollments_count: 1,
                  reprocess_delay_minutes: 5,
                  job_name: described_class.name,
                )
              end

              it 'logs the job enrollment updated analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_enrollment_updated,
                ).with(
                  **enrollment_analytics,
                  minutes_to_completion: nil,
                  **response_analytics,
                  response_message: response_message,
                  passed: false,
                  reason: 'Invalid applicant unique id',
                  job_name: described_class.name,
                  tmx_status: enrollment.profile&.tmx_status,
                  profile_age_in_seconds: instance_of(Integer),
                  enhanced_ipp: enrollment.enhanced_ipp?,
                )
              end

              it 'cancels the enrollment' do
                expect(enrollment.reload).to have_attributes(
                  status_check_attempted_at: current_time,
                  last_batch_claimed_at: current_time,
                  status: 'cancelled',
                )
              end

              it "deactivates the enrollment's profile" do
                expect(enrollment.reload.profile).to have_attributes(
                  active: false,
                  deactivation_reason: 'verification_cancelled',
                  in_person_verification_pending_at: nil,
                )
              end

              it 'logs the job unexpected response analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_unexpected_response,
                ).with(
                  **enrollment_analytics,
                  response_message: response_message,
                  reason: 'Invalid applicant unique id',
                  job_name: described_class.name,
                )
              end

              it 'logs the job completed analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_completed,
                ).with(
                  **default_job_completion_analytics,
                  enrollments_checked: 1,
                  enrollments_cancelled: 1,
                )
              end
            end

            context 'when the exception response message is IPP_BAD_SPONSOR_ID' do
              let(:response_message) do
                "sponsorID #{enrollment.sponsor_id} is not registered as an IPP client"
              end

              before do
                stub_request_proofing_results(
                  status_code: 400,
                  body: { responseMessage: response_message },
                )
                allow(analytics).to receive(
                  :idv_in_person_usps_proofing_results_job_exception,
                )
                subject.perform(current_time)
              end

              it 'logs the job started analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_started,
                ).with(
                  enrollments_count: 1,
                  reprocess_delay_minutes: 5,
                  job_name: described_class.name,
                )
              end

              it 'updates the enrollment status check timestamps' do
                expect(enrollment.reload).to have_attributes(
                  status_check_attempted_at: current_time,
                  last_batch_claimed_at: current_time,
                )
              end

              it 'notifies new relic with the error' do
                expect(NewRelic::Agent).to have_received(:notice_error).with(
                  instance_of(Faraday::BadRequestError),
                )
              end

              it 'logs the job exception analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_exception,
                ).with(
                  **enrollment_analytics,
                  minutes_to_completion: nil,
                  **response_analytics,
                  response_message: 'sponsorID [FILTERED] is not registered as an IPP client',
                  exception_class: 'Faraday::BadRequestError',
                  exception_message: 'the server responded with status 400',
                  reason: 'Request exception',
                  response_status_code: 400,
                  job_name: described_class.name,
                )
              end

              it 'logs the job completed analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_completed,
                ).with(
                  **default_job_completion_analytics,
                  enrollments_checked: 1,
                  enrollments_errored: 1,
                  percent_enrollments_errored: 100.0,
                )
              end
            end

            context 'when the exception response message is IPP_SPONSOR_ID_NOT_FOUND' do
              let(:response_message) { "Sponsor for sponsorID #{enrollment.sponsor_id} not found" }

              before do
                stub_request_proofing_results(
                  status_code: 400,
                  body: { responseMessage: response_message },
                )
                allow(analytics).to receive(
                  :idv_in_person_usps_proofing_results_job_exception,
                )
                subject.perform(current_time)
              end

              it 'logs the job started analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_started,
                ).with(
                  enrollments_count: 1,
                  reprocess_delay_minutes: 5,
                  job_name: described_class.name,
                )
              end

              it 'updates the enrollment status check timestamps' do
                expect(enrollment.reload).to have_attributes(
                  status_check_attempted_at: current_time,
                  last_batch_claimed_at: current_time,
                )
              end

              it 'notifies new relic with the error' do
                expect(NewRelic::Agent).to have_received(:notice_error).with(
                  instance_of(Faraday::BadRequestError),
                )
              end

              it 'logs the job exception analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_exception,
                ).with(
                  **enrollment_analytics,
                  minutes_to_completion: nil,
                  **response_analytics,
                  response_message: 'Sponsor for sponsorID [FILTERED] not found',
                  exception_class: 'Faraday::BadRequestError',
                  exception_message: 'the server responded with status 400',
                  reason: 'Request exception',
                  response_status_code: 400,
                  job_name: described_class.name,
                )
              end

              it 'logs the job completed analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_completed,
                ).with(
                  **default_job_completion_analytics,
                  enrollments_checked: 1,
                  enrollments_errored: 1,
                  percent_enrollments_errored: 100.0,
                )
              end
            end

            context 'when the exception response message is unhandled' do
              let(:response_message) { 'I am error' }

              before do
                stub_request_proofing_results(
                  status_code: 400,
                  body: { responseMessage: response_message },
                )
                allow(analytics).to receive(:idv_in_person_usps_proofing_results_job_exception)
                subject.perform(current_time)
              end

              it 'logs the job started analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_started,
                ).with(
                  enrollments_count: 1,
                  reprocess_delay_minutes: 5,
                  job_name: described_class.name,
                )
              end

              it 'notifies new relic with the error' do
                expect(NewRelic::Agent).to have_received(:notice_error)
              end

              it 'logs the job exception analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_exception,
                ).with(
                  **enrollment_analytics,
                  minutes_to_completion: nil,
                  **response_analytics,
                  response_message: response_message,
                  exception_class: 'Faraday::BadRequestError',
                  exception_message: 'the server responded with status 400',
                  reason: 'Request exception',
                  response_status_code: 400,
                  job_name: described_class.name,
                )
              end

              it 'updates the enrollment status check timestamps' do
                expect(enrollment.reload).to have_attributes(
                  status_check_attempted_at: current_time,
                  last_batch_claimed_at: current_time,
                )
              end

              it 'logs the job completed analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_completed,
                ).with(
                  **default_job_completion_analytics,
                  enrollments_checked: 1,
                  enrollments_errored: 1,
                  percent_enrollments_errored: 100.0,
                )
              end
            end
          end

          context 'when the exception is a Faraday::ClientError' do
            before do
              stub_request_proofing_results(status_code: 403, body: {})
              allow(analytics).to receive(:idv_in_person_usps_proofing_results_job_exception)
              subject.perform(current_time)
            end

            it 'logs the job started analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_started,
              ).with(
                enrollments_count: 1,
                reprocess_delay_minutes: 5,
                job_name: described_class.name,
              )
            end

            it 'notifies new relic with the error' do
              expect(NewRelic::Agent).to have_received(:notice_error).with(
                instance_of(Faraday::ForbiddenError),
              )
            end

            it 'logs the job exception analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_exception,
              ).with(
                **enrollment_analytics,
                minutes_to_completion: nil,
                response_present: false,
                exception_class: 'Faraday::ForbiddenError',
                exception_message: 'the server responded with status 403',
                reason: 'Request exception',
                response_status_code: 403,
                job_name: described_class.name,
              )
            end

            it 'updates the enrollment status check timestamps' do
              expect(enrollment.reload).to have_attributes(
                status_check_attempted_at: current_time,
                last_batch_claimed_at: current_time,
              )
            end

            it 'logs the job completed analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_completed,
              ).with(
                **default_job_completion_analytics,
                enrollments_checked: 1,
                enrollments_errored: 1,
                percent_enrollments_errored: 100.0,
              )
            end
          end

          context 'when the exception is a Faraday::ServerError' do
            before do
              stub_request_proofing_results(status_code: 500, body: {})
              allow(analytics).to receive(:idv_in_person_usps_proofing_results_job_exception)
              subject.perform(current_time)
            end

            it 'logs the job started analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_started,
              ).with(
                enrollments_count: 1,
                reprocess_delay_minutes: 5,
                job_name: described_class.name,
              )
            end

            it 'notifies new relic with the error' do
              expect(NewRelic::Agent).to have_received(:notice_error).with(
                instance_of(Faraday::ServerError),
              )
            end

            it 'logs the job exception analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_exception,
              ).with(
                **enrollment_analytics,
                minutes_to_completion: nil,
                response_present: false,
                exception_class: 'Faraday::ServerError',
                exception_message: 'the server responded with status 500',
                reason: 'Request exception',
                response_status_code: 500,
                job_name: described_class.name,
              )
            end

            it 'updates the enrollment status check timestamps' do
              expect(enrollment.reload).to have_attributes(
                status_check_attempted_at: current_time,
                last_batch_claimed_at: current_time,
              )
            end

            it 'logs the job completed analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_completed,
              ).with(
                **default_job_completion_analytics,
                enrollments_checked: 1,
                enrollments_errored: 1,
                percent_enrollments_errored: 100.0,
              )
            end
          end

          context 'when the exception is a Faraday::Error' do
            context 'when the exception is a Faraday::TimeoutError' do
              before do
                stub_request_proofing_results_with_timeout_error
                allow(analytics).to receive(:idv_in_person_usps_proofing_results_job_exception)
                subject.perform(current_time)
              end

              it 'logs the job started analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_started,
                ).with(
                  enrollments_count: 1,
                  reprocess_delay_minutes: 5,
                  job_name: described_class.name,
                )
              end

              it 'notifies new relic with the error' do
                expect(NewRelic::Agent).to have_received(:notice_error).with(
                  instance_of(Faraday::TimeoutError),
                )
              end

              it 'logs the job exception analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_exception,
                ).with(
                  **enrollment_analytics,
                  minutes_to_completion: nil,
                  response_present: false,
                  exception_class: 'Faraday::TimeoutError',
                  exception_message: 'Exception from WebMock',
                  reason: 'Request exception',
                  response_status_code: nil,
                  job_name: described_class.name,
                )
              end

              it 'updates the enrollment status check timestamps' do
                expect(enrollment.reload).to have_attributes(
                  status_check_attempted_at: current_time,
                  last_batch_claimed_at: current_time,
                )
              end

              it 'logs the job completed analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_completed,
                ).with(
                  **default_job_completion_analytics,
                  enrollments_checked: 1,
                  enrollments_network_error: 1,
                  percent_enrollments_network_error: 100.0,
                )
              end
            end

            context 'when the exception is a Faraday::ConnectionFailed' do
              before do
                stub_request(
                  :post,
                  %r{/ivs-ippaas-api/IPPRest/resources/rest/getProofingResults},
                ).to_timeout
                allow(analytics).to receive(:idv_in_person_usps_proofing_results_job_exception)
                subject.perform(current_time)
              end

              it 'logs the job started analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_started,
                ).with(
                  enrollments_count: 1,
                  reprocess_delay_minutes: 5,
                  job_name: described_class.name,
                )
              end

              it 'notifies new relic with the error' do
                expect(NewRelic::Agent).to have_received(:notice_error).with(
                  instance_of(Faraday::ConnectionFailed),
                )
              end

              it 'logs the job exception analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_exception,
                ).with(
                  **enrollment_analytics,
                  minutes_to_completion: nil,
                  response_present: false,
                  exception_class: 'Faraday::ConnectionFailed',
                  exception_message: 'execution expired',
                  reason: 'Request exception',
                  response_status_code: nil,
                  job_name: described_class.name,
                )
              end

              it 'updates the enrollment status check timestamps' do
                expect(enrollment.reload).to have_attributes(
                  status_check_attempted_at: current_time,
                  last_batch_claimed_at: current_time,
                )
              end

              it 'logs the job completed analytic' do
                expect(analytics).to have_received(
                  :idv_in_person_usps_proofing_results_job_completed,
                ).with(
                  **default_job_completion_analytics,
                  enrollments_checked: 1,
                  enrollments_network_error: 1,
                  percent_enrollments_network_error: 100.0,
                )
              end
            end
          end

          context 'when the exception is a StandardError' do
            before do
              allow(analytics).to receive(:idv_in_person_usps_proofing_results_job_exception)
              allow(UspsInPersonProofing::EnrollmentHelper).to receive(
                :usps_proofer,
              ).and_raise(StandardError)
              subject.perform(current_time)
            end

            it 'logs the job started analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_started,
              ).with(
                enrollments_count: 1,
                reprocess_delay_minutes: 5,
                job_name: described_class.name,
              )
            end

            it 'notifies new relic with the error' do
              expect(NewRelic::Agent).to have_received(:notice_error).with(
                instance_of(StandardError),
              )
            end

            it 'logs the job exception analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_exception,
              ).with(
                **enrollment_analytics,
                minutes_to_completion: nil,
                response_present: false,
                exception_class: 'StandardError',
                exception_message: 'StandardError',
                reason: 'Request exception',
                job_name: described_class.name,
              )
            end

            it 'updates the enrollment status check timestamps' do
              expect(enrollment.reload).to have_attributes(
                status_check_attempted_at: current_time,
                last_batch_claimed_at: current_time,
              )
            end

            it 'logs the job completed analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_completed,
              ).with(
                **default_job_completion_analytics,
                enrollments_checked: 1,
                enrollments_errored: 1,
                percent_enrollments_errored: 100.0,
              )
            end
          end
        end

        context 'when the USPS client request proofing results is successful' do
          before do
            allow(IdentityConfig.store).to receive(
              :in_person_send_proofing_notifications_enabled,
            ).and_return(true)
          end

          context 'when the enrollment has a deactivation reason of password_reset' do
            let(:deactivation_reason) { 'password_reset' }
            let(:in_person_verification_pending_at) do
              enrollment.profile.in_person_verification_pending_at
            end

            before do
              enrollment.profile.update(deactivation_reason: deactivation_reason)
              stub_request_passed_proofing_results
              allow(analytics).to receive(
                :idv_in_person_usps_proofing_results_job_enrollment_skipped,
              )
              allow(analytics).to receive(:idv_in_person_usps_proofing_results_job_exception)
              subject.perform(current_time)
            end

            it 'logs the job started analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_started,
              ).with(
                enrollments_count: 1,
                reprocess_delay_minutes: 5,
                job_name: described_class.name,
              )
            end

            it 'updates the enrollment status check timestamps' do
              expect(enrollment.reload).to have_attributes(
                status_check_attempted_at: current_time,
                last_batch_claimed_at: current_time,
              )
            end

            it 'logs the job enrollment skipped analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_enrollment_skipped,
              ).with(
                **enrollment_analytics,
                minutes_to_completion: nil,
                reason: "Profile has a deactivation reason of #{deactivation_reason}",
                job_name: described_class.name,
              )
            end

            it 'does not cancel the enrollment' do
              expect(enrollment.reload).to have_attributes(
                status: 'pending',
              )
            end

            it "does not update the enrollment's profile" do
              expect(enrollment.reload.profile).to have_attributes(
                active: false,
                deactivation_reason:,
                in_person_verification_pending_at:,
              )
            end

            it 'logs the job completed analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_completed,
              ).with(
                **default_job_completion_analytics,
                enrollments_checked: 1,
                enrollments_skipped: 1,
              )
            end
          end

          context 'when the USPS proofing results is not a hash' do
            before do
              stub_request_proofing_results(
                status_code: 200,
                body: ['I am not what you think I am'],
              )
              allow(analytics).to receive(:idv_in_person_usps_proofing_results_job_exception)
              subject.perform(current_time)
            end

            it 'logs the job started analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_started,
              ).with(
                enrollments_count: 1,
                reprocess_delay_minutes: 5,
                job_name: described_class.name,
              )
            end

            it 'logs the job exception analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_exception,
              ).with(
                **enrollment_analytics,
                minutes_to_completion: nil,
                reason: 'Bad response structure',
                job_name: described_class.name,
              )
            end

            it 'updates the enrollment status check timestamps' do
              expect(enrollment.reload).to have_attributes(
                status_check_attempted_at: current_time,
                last_batch_claimed_at: current_time,
              )
            end

            it 'logs the job completed analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_completed,
              ).with(
                **default_job_completion_analytics,
                enrollments_checked: 1,
                enrollments_errored: 1,
                percent_enrollments_errored: 100.0,
              )
            end
          end

          context 'when the USPS proofing results is a hash' do
            let(:usps_enrollment_start_date) do
              current_time.getlocal('-0600')
            end

            let(:usps_enrollment_end_date) do
              (current_time + in_person_results_delay_in_hours.hour).getlocal('-0600')
            end

            let(:response_body) do
              {
                status: 'In-person passed',
                proofingPostOffice: 'WILKES BARRE',
                proofingCity: 'WILKES BARRE',
                proofingState: 'PA',
                enrollmentCode: enrollment.enrollment_code,
                primaryIdType: "State driver's license",
                transactionStartDateTime:
                  usps_enrollment_start_date.strftime('%m/%d/%Y %H%M%S'),
                transactionEndDateTime: usps_enrollment_end_date.strftime('%m/%d/%Y %H%M%S'),
                fraudSuspected: false,
                proofingConfirmationNumber: '350040248346701',
                ippAssuranceLevel: '1.5',
              }
            end

            let(:response_analytics) do
              {
                fraud_suspected: response_body[:fraudSuspected],
                primary_id_type: response_body[:primaryIdType],
                secondary_id_type: response_body[:secondaryIdType],
                failure_reason: response_body[:failureReason],
                transaction_end_date_time: usps_enrollment_end_date.getlocal('UTC'),
                transaction_start_date_time: usps_enrollment_start_date.getlocal('UTC'),
                status: response_body[:status],
                assurance_level: response_body[:assuranceLevel],
                proofing_post_office: response_body[:proofingPostOffice],
                proofing_city: response_body[:proofingCity],
                proofing_state: response_body[:proofingState],
                scan_count: response_body[:scanCount],
                response_message: response_body[:responseMessage],
                response_present: true,
              }
            end

            context 'when the InPersonEnrollment has fraud results pending' do
              before do
                allow(IdentityConfig.store).to receive(
                  :in_person_proofing_enforce_tmx,
                ).and_return(true)
                enrollment.profile.update(
                  fraud_pending_reason: 'threatmetrix_review',
                  proofing_components: { threatmetrix_review_status: 'review' },
                )
              end

              context 'when the USPS proofing results has a passing status' do
                before do
                  stub_request_proofing_results(status_code: 200, body: response_body)
                  allow(analytics).to receive(
                    :idv_in_person_usps_proofing_results_job_user_sent_to_fraud_review,
                  )
                  allow(analytics).to receive(
                    :idv_in_person_usps_proofing_results_job_enrollment_updated,
                  )
                  allow(analytics).to receive(
                    :idv_in_person_usps_proofing_results_job_please_call_email_initiated,
                  )
                  allow(user_mailer).to receive(:idv_please_call).and_return(mail_deliverer)
                  subject.perform(current_time)
                end

                it 'logs the job started analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_started,
                  ).with(
                    enrollments_count: 1,
                    reprocess_delay_minutes: 5,
                    job_name: described_class.name,
                  )
                end

                it "deactivates the enrollment's profile for fraud review" do
                  expect(enrollment.reload.profile).to have_attributes(
                    active: false,
                    fraud_review_pending_at: Time.zone.now,
                    fraud_rejection_at: nil,
                    in_person_verification_pending_at: nil,
                  )
                end

                it 'logs the job user sent to fraud review analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_user_sent_to_fraud_review,
                  ).with(**enrollment_analytics)
                end

                it 'logs the job enrollment updated analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_enrollment_updated,
                  ).with(
                    **enrollment_analytics,
                    **response_analytics,
                    passed: true,
                    reason: 'Passed with fraud pending',
                    job_name: described_class.name,
                    tmx_status: 'threatmetrix_review',
                    profile_age_in_seconds: enrollment.profile&.profile_age_in_seconds,
                    enhanced_ipp: false,
                  )
                end

                it 'passes the enrollment' do
                  expect(enrollment.reload).to have_attributes(
                    status: 'passed',
                    proofed_at: usps_enrollment_end_date.getlocal('UTC'),
                    status_check_attempted_at: current_time,
                    status_check_completed_at: current_time,
                    last_batch_claimed_at: current_time,
                  )
                end

                it 'sends the please call email' do
                  expect(user_mailer).to have_received(:idv_please_call).with(
                    enrollment: enrollment,
                    visited_location_name: visited_location_name,
                  )
                  expect(mail_deliverer).to have_received(:deliver_later).with(
                    queue: :intentionally_delayed,
                    wait_until: (enrollment.reload.status_check_completed_at +
                      in_person_results_delay_in_hours.hour),
                  )
                end

                it 'logs the job please call email initiated analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_please_call_email_initiated,
                  ).with(
                    enrollment_code: enrollment.enrollment_code,
                    timestamp: current_time,
                    wait_until: (enrollment.reload.status_check_completed_at +
                      in_person_results_delay_in_hours.hour),
                    service_provider: enrollment.issuer,
                    job_name: described_class.name,
                  )
                end

                it 'logs the job completed analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_completed,
                  ).with(
                    **default_job_completion_analytics,
                    enrollments_checked: 1,
                    enrollments_passed: 1,
                  )
                end
              end

              context 'when the USPS proofing results has a failed status' do
                before do
                  response_body[:status] = 'In-person failed'
                  response_body[:failureReason] = 'Address does not match source data.'
                  response_body[:fraudSuspected] = false
                  stub_request_proofing_results(status_code: 200, body: response_body)
                  allow(analytics).to receive(
                    :idv_in_person_usps_proofing_results_job_user_sent_to_fraud_review,
                  )
                  allow(analytics).to receive(
                    :idv_in_person_usps_proofing_results_job_enrollment_updated,
                  )
                  allow(analytics).to receive(
                    :idv_in_person_usps_proofing_results_job_email_initiated,
                  )
                  allow(user_mailer).to receive(:in_person_failed).and_return(mail_deliverer)
                  subject.perform(current_time)
                end

                it 'logs the job started analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_started,
                  ).with(
                    enrollments_count: 1,
                    reprocess_delay_minutes: 5,
                    job_name: described_class.name,
                  )
                end

                it 'logs the job user sent to fraud review analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_user_sent_to_fraud_review,
                  ).with(**enrollment_analytics)
                end

                it 'logs the job enrollment updated analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_enrollment_updated,
                  ).with(
                    **enrollment_analytics,
                    **response_analytics,
                    passed: false,
                    reason: 'Failed status',
                    job_name: described_class.name,
                    tmx_status: 'threatmetrix_review',
                    profile_age_in_seconds: enrollment.profile&.profile_age_in_seconds,
                    enhanced_ipp: false,
                  )
                end

                it 'fails the enrollment' do
                  expect(enrollment.reload).to have_attributes(
                    status: 'failed',
                    proofed_at: usps_enrollment_end_date.getlocal('UTC'),
                    status_check_attempted_at: current_time,
                    status_check_completed_at: current_time,
                    last_batch_claimed_at: current_time,
                  )
                end

                it "deactivates the enrollment's profile" do
                  expect(enrollment.reload.profile).to have_attributes(
                    active: false,
                    fraud_review_pending_at: Time.zone.now,
                    fraud_rejection_at: nil,
                    deactivation_reason: 'verification_cancelled',
                    in_person_verification_pending_at: nil,
                  )
                end

                it 'sends a proofing sms notification' do
                  expect(send_proofing_notification_job).to have_received(
                    :perform_later,
                  ).with(enrollment.id)
                end

                it 'sends the in person failed email' do
                  expect(user_mailer).to have_received(:in_person_failed).with(
                    enrollment: enrollment,
                    visited_location_name: visited_location_name,
                  )
                  expect(mail_deliverer).to have_received(:deliver_later).with(
                    queue: :intentionally_delayed,
                    wait_until: (enrollment.reload.status_check_completed_at +
                      in_person_results_delay_in_hours.hour),
                  )
                end

                it 'logs the job email initiated analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_email_initiated,
                  ).with(
                    enrollment_code: enrollment.enrollment_code,
                    timestamp: current_time,
                    wait_until: (enrollment.reload.status_check_completed_at +
                      in_person_results_delay_in_hours.hour),
                    service_provider: enrollment.issuer,
                    email_type: 'Failed',
                    job_name: described_class.name,
                  )
                end

                it 'logs the job completed analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_completed,
                  ).with(
                    **default_job_completion_analytics,
                    enrollments_checked: 1,
                    enrollments_failed: 1,
                  )
                end
              end
            end

            context 'when the InPersonEnrollment does not have fraud results pending' do
              context 'when the USPS proofing results has a passed status' do
                context 'when the InPersonEnrollment is an ID-IPP enrollment' do
                  context 'when proofing passed with an unsupported secondary id type' do
                    before do
                      response_body[:secondaryIdType] = 'Unsupported'
                      stub_request_proofing_results(status_code: 200, body: response_body)
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      )
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_email_initiated,
                      )
                      allow(user_mailer).to receive(:in_person_failed).and_return(mail_deliverer)
                      subject.perform(current_time)
                    end

                    it 'logs the job started analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_started,
                      ).with(
                        enrollments_count: 1,
                        reprocess_delay_minutes: 5,
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job enrollment updated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      ).with(
                        **enrollment_analytics,
                        **response_analytics,
                        passed: false,
                        reason: 'Provided secondary proof of address',
                        job_name: described_class.name,
                        tmx_status: nil,
                        profile_age_in_seconds: enrollment.profile&.profile_age_in_seconds,
                        enhanced_ipp: false,
                      )
                    end

                    it 'fails the enrollment' do
                      expect(enrollment.reload).to have_attributes(
                        status: 'failed',
                        proofed_at: usps_enrollment_end_date.getlocal('UTC'),
                        status_check_attempted_at: current_time,
                        status_check_completed_at: current_time,
                        last_batch_claimed_at: current_time,
                      )
                    end

                    it "deactivates the enrollment's profile" do
                      expect(enrollment.reload.profile).to have_attributes(
                        active: false,
                        deactivation_reason: 'verification_cancelled',
                        in_person_verification_pending_at: nil,
                      )
                    end

                    it 'sends a proofing sms notification' do
                      expect(send_proofing_notification_job).to have_received(
                        :perform_later,
                      ).with(enrollment.id)
                    end

                    it 'sends the in person failed email with delay' do
                      expect(user_mailer).to have_received(:in_person_failed).with(
                        enrollment: enrollment,
                        visited_location_name: visited_location_name,
                      )
                      expect(mail_deliverer).to have_received(:deliver_later).with(
                        queue: :intentionally_delayed,
                        wait_until: (enrollment.reload.status_check_completed_at +
                          in_person_results_delay_in_hours.hour),
                      )
                    end

                    it 'logs the job email initiated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_email_initiated,
                      ).with(
                        enrollment_code: enrollment.enrollment_code,
                        timestamp: current_time,
                        wait_until: (enrollment.reload.status_check_completed_at +
                          in_person_results_delay_in_hours.hour),
                        service_provider: enrollment.issuer,
                        email_type: 'Failed unsupported secondary ID',
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job completed analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_completed,
                      ).with(
                        **default_job_completion_analytics,
                        enrollments_checked: 1,
                        enrollments_failed: 1,
                      )
                    end
                  end

                  context 'when proofing passed with a primary id type' do
                    before do
                      stub_request_proofing_results(status_code: 200, body: response_body)
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      )
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_email_initiated,
                      )
                      allow(user_mailer).to receive(:in_person_verified).and_return(mail_deliverer)
                      subject.perform(current_time)
                    end

                    it 'logs the job started analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_started,
                      ).with(
                        enrollments_count: 1,
                        reprocess_delay_minutes: 5,
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job enrollment updated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      ).with(
                        **enrollment_analytics,
                        **response_analytics,
                        passed: true,
                        reason: 'Successful status update',
                        job_name: described_class.name,
                        tmx_status: nil,
                        profile_age_in_seconds: enrollment.profile&.profile_age_in_seconds,
                        enhanced_ipp: false,
                      )
                    end

                    it 'passes the enrollment' do
                      expect(enrollment.reload).to have_attributes(
                        status: 'passed',
                        proofed_at: usps_enrollment_end_date.getlocal('UTC'),
                        status_check_attempted_at: current_time,
                        status_check_completed_at: current_time,
                        last_batch_claimed_at: current_time,
                      )
                    end

                    it "activates the enrollment's profile" do
                      expect(enrollment.reload.profile).to have_attributes(
                        active: true,
                        deactivation_reason: nil,
                        in_person_verification_pending_at: nil,
                      )
                    end

                    it 'sends a proofing sms notification' do
                      expect(send_proofing_notification_job).to have_received(
                        :perform_later,
                      ).with(enrollment.id)
                    end

                    it 'sends the in person verified email with a delay' do
                      expect(user_mailer).to have_received(:in_person_verified).with(
                        enrollment: enrollment,
                        visited_location_name: visited_location_name,
                      )
                      expect(mail_deliverer).to have_received(:deliver_later).with(
                        queue: :intentionally_delayed,
                        wait_until: (enrollment.reload.status_check_completed_at +
                          in_person_results_delay_in_hours.hour),
                      )
                    end

                    it 'logs the job email initiated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_email_initiated,
                      ).with(
                        enrollment_code: enrollment.enrollment_code,
                        timestamp: current_time,
                        wait_until: (enrollment.reload.status_check_completed_at +
                          in_person_results_delay_in_hours.hour),
                        service_provider: enrollment.issuer,
                        email_type: 'Success',
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job completed analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_completed,
                      ).with(
                        **default_job_completion_analytics,
                        enrollments_checked: 1,
                        enrollments_passed: 1,
                      )
                    end
                  end

                  context 'when proofing passed with an unsupported id type' do
                    before do
                      response_body[:primaryIdType] = 'Unsupported'
                      stub_request_proofing_results(status_code: 200, body: response_body)
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      )
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_email_initiated,
                      )
                      allow(user_mailer).to receive(:in_person_failed).and_return(mail_deliverer)
                      subject.perform(current_time)
                    end

                    it 'logs the job started analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_started,
                      ).with(
                        enrollments_count: 1,
                        reprocess_delay_minutes: 5,
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job enrollment updated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      ).with(
                        **enrollment_analytics,
                        **response_analytics,
                        passed: false,
                        reason: 'Unsupported ID type',
                        job_name: described_class.name,
                        tmx_status: nil,
                        profile_age_in_seconds: enrollment.profile&.profile_age_in_seconds,
                        enhanced_ipp: false,
                      )
                    end

                    it 'fails the enrollment' do
                      expect(enrollment.reload).to have_attributes(
                        status: 'failed',
                        proofed_at: usps_enrollment_end_date.getlocal('UTC'),
                        status_check_attempted_at: current_time,
                        status_check_completed_at: current_time,
                        last_batch_claimed_at: current_time,
                      )
                    end

                    it "deactivates the enrollment's profile" do
                      expect(enrollment.reload.profile).to have_attributes(
                        active: false,
                        deactivation_reason: 'verification_cancelled',
                        in_person_verification_pending_at: nil,
                      )
                    end

                    it 'sends a proofing sms notification' do
                      expect(send_proofing_notification_job).to have_received(
                        :perform_later,
                      ).with(enrollment.id)
                    end

                    it 'sends the in person failed email with delay' do
                      expect(user_mailer).to have_received(:in_person_failed).with(
                        enrollment: enrollment,
                        visited_location_name: visited_location_name,
                      )
                      expect(mail_deliverer).to have_received(:deliver_later).with(
                        queue: :intentionally_delayed,
                        wait_until: (enrollment.reload.status_check_completed_at +
                          in_person_results_delay_in_hours.hour),
                      )
                    end

                    it 'logs the job email initiated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_email_initiated,
                      ).with(
                        enrollment_code: enrollment.enrollment_code,
                        timestamp: current_time,
                        wait_until: (enrollment.reload.status_check_completed_at +
                          in_person_results_delay_in_hours.hour),
                        service_provider: enrollment.issuer,
                        email_type: 'Failed unsupported ID type',
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job completed analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_completed,
                      ).with(
                        **default_job_completion_analytics,
                        enrollments_checked: 1,
                        enrollments_failed: 1,
                      )
                    end
                  end
                end

                context 'when the InPersonEnrollment is an EIPP enrollment' do
                  let!(:enrollment) do
                    create(
                      :in_person_enrollment,
                      :pending,
                      :enhanced_ipp,
                      :with_notification_phone_configuration,
                    )
                  end

                  before do
                    response_body[:ippAssuranceLevel] = '2.0'
                    allow(InPersonEnrollment).to receive(:needs_usps_status_check).and_return(
                      InPersonEnrollment.where(
                        status: :pending,
                        sponsor_id: IdentityConfig.store.usps_eipp_sponsor_id,
                      ),
                    )
                  end

                  context 'when proofing passed with an unsupported secondary id type' do
                    before do
                      response_body[:secondaryIdType] = 'Unsupported'
                      stub_request_proofing_results(status_code: 200, body: response_body)
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      )
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_email_initiated,
                      )
                      allow(user_mailer).to receive(:in_person_verified).and_return(mail_deliverer)
                      subject.perform(current_time)
                    end

                    it 'logs the job started analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_started,
                      ).with(
                        enrollments_count: 1,
                        reprocess_delay_minutes: 5,
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job enrollment updated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      ).with(
                        **enrollment_analytics,
                        **response_analytics,
                        passed: true,
                        reason: 'Successful status update',
                        job_name: described_class.name,
                        tmx_status: nil,
                        profile_age_in_seconds: enrollment.profile&.profile_age_in_seconds,
                        enhanced_ipp: true,
                      )
                    end

                    it 'passes the enrollment' do
                      expect(enrollment.reload).to have_attributes(
                        status: 'passed',
                        proofed_at: usps_enrollment_end_date.getlocal('UTC'),
                        status_check_attempted_at: current_time,
                        status_check_completed_at: current_time,
                        last_batch_claimed_at: current_time,
                      )
                    end

                    it "activates the enrollment's profile" do
                      expect(enrollment.reload.profile).to have_attributes(
                        active: true,
                        deactivation_reason: nil,
                        in_person_verification_pending_at: nil,
                      )
                    end

                    it 'sends a proofing sms notification' do
                      expect(send_proofing_notification_job).to have_received(
                        :perform_later,
                      ).with(enrollment.id)
                    end

                    it 'sends the in person verified email with delay' do
                      expect(user_mailer).to have_received(:in_person_verified).with(
                        enrollment: enrollment,
                        visited_location_name: visited_location_name,
                      )
                      expect(mail_deliverer).to have_received(:deliver_later).with(
                        queue: :intentionally_delayed,
                        wait_until: (enrollment.reload.status_check_completed_at +
                          in_person_results_delay_in_hours.hour),
                      )
                    end

                    it 'logs the job email initiated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_email_initiated,
                      ).with(
                        enrollment_code: enrollment.enrollment_code,
                        timestamp: current_time,
                        wait_until: (enrollment.reload.status_check_completed_at +
                          in_person_results_delay_in_hours.hour),
                        service_provider: enrollment.issuer,
                        email_type: 'Success',
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job completed analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_completed,
                      ).with(
                        **default_job_completion_analytics,
                        enrollments_checked: 1,
                        enrollments_passed: 1,
                      )
                    end
                  end

                  context 'when proofing passed with a primary id type' do
                    before do
                      stub_request_proofing_results(status_code: 200, body: response_body)
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      )
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_email_initiated,
                      )
                      allow(user_mailer).to receive(:in_person_verified).and_return(mail_deliverer)
                      subject.perform(current_time)
                    end

                    it 'logs the job started analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_started,
                      ).with(
                        enrollments_count: 1,
                        reprocess_delay_minutes: 5,
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job enrollment updated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      ).with(
                        **enrollment_analytics,
                        **response_analytics,
                        passed: true,
                        reason: 'Successful status update',
                        job_name: described_class.name,
                        tmx_status: nil,
                        profile_age_in_seconds: enrollment.profile&.profile_age_in_seconds,
                        enhanced_ipp: true,
                      )
                    end

                    it 'passes the enrollment' do
                      expect(enrollment.reload).to have_attributes(
                        status: 'passed',
                        proofed_at: usps_enrollment_end_date.getlocal('UTC'),
                        status_check_attempted_at: current_time,
                        status_check_completed_at: current_time,
                        last_batch_claimed_at: current_time,
                      )
                    end

                    it "activates the enrollment's profile" do
                      expect(enrollment.reload.profile).to have_attributes(
                        active: true,
                        deactivation_reason: nil,
                        in_person_verification_pending_at: nil,
                      )
                    end

                    it 'sends a proofing sms notification' do
                      expect(send_proofing_notification_job).to have_received(
                        :perform_later,
                      ).with(enrollment.id)
                    end

                    it 'sends the in person verified email' do
                      expect(user_mailer).to have_received(:in_person_verified).with(
                        enrollment: enrollment,
                        visited_location_name: visited_location_name,
                      )
                      expect(mail_deliverer).to have_received(:deliver_later).with(
                        queue: :intentionally_delayed,
                        wait_until: (enrollment.reload.status_check_completed_at +
                          in_person_results_delay_in_hours.hour),
                      )
                    end

                    it 'logs the job email initiated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_email_initiated,
                      ).with(
                        enrollment_code: enrollment.enrollment_code,
                        timestamp: current_time,
                        wait_until: (enrollment.reload.status_check_completed_at +
                          in_person_results_delay_in_hours.hour),
                        service_provider: enrollment.issuer,
                        email_type: 'Success',
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job completed analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_completed,
                      ).with(
                        **default_job_completion_analytics,
                        enrollments_checked: 1,
                        enrollments_passed: 1,
                      )
                    end
                  end

                  context 'when proofing passed with an unsupported id type' do
                    before do
                      response_body[:primaryIdType] = 'Unsupported'
                      stub_request_proofing_results(status_code: 200, body: response_body)
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      )
                      allow(analytics).to receive(
                        :idv_in_person_usps_proofing_results_job_email_initiated,
                      )
                      allow(user_mailer).to receive(:in_person_verified).and_return(mail_deliverer)
                      subject.perform(current_time)
                    end

                    it 'logs the job started analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_started,
                      ).with(
                        enrollments_count: 1,
                        reprocess_delay_minutes: 5,
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job enrollment updated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_enrollment_updated,
                      ).with(
                        **enrollment_analytics,
                        **response_analytics,
                        passed: true,
                        reason: 'Successful status update',
                        job_name: described_class.name,
                        tmx_status: nil,
                        profile_age_in_seconds: enrollment.profile&.profile_age_in_seconds,
                        enhanced_ipp: true,
                      )
                    end

                    it 'passes the enrollment' do
                      expect(enrollment.reload).to have_attributes(
                        status: 'passed',
                        proofed_at: usps_enrollment_end_date.getlocal('UTC'),
                        status_check_attempted_at: current_time,
                        status_check_completed_at: current_time,
                        last_batch_claimed_at: current_time,
                      )
                    end

                    it "activates the enrollment's profile" do
                      expect(enrollment.reload.profile).to have_attributes(
                        active: true,
                        deactivation_reason: nil,
                        in_person_verification_pending_at: nil,
                      )
                    end

                    it 'sends a proofing sms notification' do
                      expect(send_proofing_notification_job).to have_received(
                        :perform_later,
                      ).with(enrollment.id)
                    end

                    it 'sends the in person verified email' do
                      expect(user_mailer).to have_received(:in_person_verified).with(
                        enrollment: enrollment,
                        visited_location_name: visited_location_name,
                      )
                      expect(mail_deliverer).to have_received(:deliver_later).with(
                        queue: :intentionally_delayed,
                        wait_until: (enrollment.reload.status_check_completed_at +
                          in_person_results_delay_in_hours.hour),
                      )
                    end

                    it 'logs the job email initiated analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_email_initiated,
                      ).with(
                        enrollment_code: enrollment.enrollment_code,
                        timestamp: current_time,
                        wait_until: (enrollment.reload.status_check_completed_at +
                          in_person_results_delay_in_hours.hour),
                        service_provider: enrollment.issuer,
                        email_type: 'Success',
                        job_name: described_class.name,
                      )
                    end

                    it 'logs the job completed analytic' do
                      expect(analytics).to have_received(
                        :idv_in_person_usps_proofing_results_job_completed,
                      ).with(
                        **default_job_completion_analytics,
                        enrollments_checked: 1,
                        enrollments_passed: 1,
                      )
                    end
                  end
                end
              end

              context 'when the USPS proofing results has a failed status' do
                context 'when he USPS proofing results does not have fraud suspected' do
                  before do
                    response_body[:status] = 'In-person failed'
                    response_body[:failureReason] = 'Address does not match source data.'
                    response_body[:fraudSuspected] = false
                    stub_request_proofing_results(status_code: 200, body: response_body)
                    allow(analytics).to receive(
                      :idv_in_person_usps_proofing_results_job_enrollment_updated,
                    )
                    allow(analytics).to receive(
                      :idv_in_person_usps_proofing_results_job_email_initiated,
                    )
                    allow(user_mailer).to receive(:in_person_failed).and_return(mail_deliverer)
                    subject.perform(current_time)
                  end

                  it 'logs the job started analytic' do
                    expect(analytics).to have_received(
                      :idv_in_person_usps_proofing_results_job_started,
                    ).with(
                      enrollments_count: 1,
                      reprocess_delay_minutes: 5,
                      job_name: described_class.name,
                    )
                  end

                  it 'logs the job enrollment updated analytic' do
                    expect(analytics).to have_received(
                      :idv_in_person_usps_proofing_results_job_enrollment_updated,
                    ).with(
                      **enrollment_analytics,
                      **response_analytics,
                      passed: false,
                      reason: 'Failed status',
                      job_name: described_class.name,
                      tmx_status: nil,
                      profile_age_in_seconds: enrollment.profile&.profile_age_in_seconds,
                      enhanced_ipp: false,
                    )
                  end

                  it 'fails the enrollment' do
                    expect(enrollment.reload).to have_attributes(
                      status: 'failed',
                      proofed_at: usps_enrollment_end_date.getlocal('UTC'),
                      status_check_attempted_at: current_time,
                      status_check_completed_at: current_time,
                      last_batch_claimed_at: current_time,
                    )
                  end

                  it "deactivates the enrollment's profile" do
                    expect(enrollment.reload.profile).to have_attributes(
                      active: false,
                      deactivation_reason: 'verification_cancelled',
                      in_person_verification_pending_at: nil,
                    )
                  end

                  it 'sends a proofing sms notification' do
                    expect(send_proofing_notification_job).to have_received(
                      :perform_later,
                    ).with(enrollment.id)
                  end

                  it 'sends the in person failed email' do
                    expect(user_mailer).to have_received(:in_person_failed).with(
                      enrollment: enrollment,
                      visited_location_name: visited_location_name,
                    )
                    expect(mail_deliverer).to have_received(:deliver_later).with(
                      queue: :intentionally_delayed,
                      wait_until: (enrollment.reload.status_check_completed_at +
                        in_person_results_delay_in_hours.hour),
                    )
                  end

                  it 'logs the job email initiated analytic' do
                    expect(analytics).to have_received(
                      :idv_in_person_usps_proofing_results_job_email_initiated,
                    ).with(
                      enrollment_code: enrollment.enrollment_code,
                      timestamp: current_time,
                      wait_until: (enrollment.reload.status_check_completed_at +
                        in_person_results_delay_in_hours.hour),
                      service_provider: enrollment.issuer,
                      email_type: 'Failed',
                      job_name: described_class.name,
                    )
                  end

                  it 'logs the job completed analytic' do
                    expect(analytics).to have_received(
                      :idv_in_person_usps_proofing_results_job_completed,
                    ).with(
                      **default_job_completion_analytics,
                      enrollments_checked: 1,
                      enrollments_failed: 1,
                    )
                  end
                end

                context 'when the USPS proofing results has fraud suspected' do
                  before do
                    response_body[:status] = 'In-person failed'
                    response_body[:failureReason] = 'Address does not match source data.'
                    response_body[:fraudSuspected] = true
                    stub_request_proofing_results(status_code: 200, body: response_body)
                    allow(analytics).to receive(
                      :idv_in_person_usps_proofing_results_job_enrollment_updated,
                    )
                    allow(analytics).to receive(
                      :idv_in_person_usps_proofing_results_job_email_initiated,
                    )
                    allow(user_mailer).to receive(:in_person_failed_fraud).and_return(
                      mail_deliverer,
                    )
                    subject.perform(current_time)
                  end

                  it 'logs the job started analytic' do
                    expect(analytics).to have_received(
                      :idv_in_person_usps_proofing_results_job_started,
                    ).with(
                      enrollments_count: 1,
                      reprocess_delay_minutes: 5,
                      job_name: described_class.name,
                    )
                  end

                  it 'logs the job enrollment updated analytic' do
                    expect(analytics).to have_received(
                      :idv_in_person_usps_proofing_results_job_enrollment_updated,
                    ).with(
                      **enrollment_analytics,
                      **response_analytics,
                      passed: false,
                      reason: 'Failed status',
                      job_name: described_class.name,
                      tmx_status: nil,
                      profile_age_in_seconds: enrollment.profile&.profile_age_in_seconds,
                      enhanced_ipp: false,
                    )
                  end

                  it 'fails the enrollment' do
                    expect(enrollment.reload).to have_attributes(
                      status: 'failed',
                      proofed_at: usps_enrollment_end_date.getlocal('UTC'),
                      status_check_attempted_at: current_time,
                      status_check_completed_at: current_time,
                      last_batch_claimed_at: current_time,
                    )
                  end

                  it "deactivates the enrollment's profile" do
                    expect(enrollment.reload.profile).to have_attributes(
                      active: false,
                      deactivation_reason: 'verification_cancelled',
                      in_person_verification_pending_at: nil,
                    )
                  end

                  it 'sends a proofing sms notification' do
                    expect(send_proofing_notification_job).to have_received(
                      :perform_later,
                    ).with(enrollment.id)
                  end

                  it 'sends the in person failed fraud email with a delay' do
                    expect(user_mailer).to have_received(:in_person_failed_fraud).with(
                      enrollment: enrollment,
                      visited_location_name: visited_location_name,
                    )
                    expect(mail_deliverer).to have_received(:deliver_later).with(
                      queue: :intentionally_delayed,
                      wait_until: (enrollment.reload.status_check_attempted_at +
                        in_person_results_delay_in_hours.hour),
                    )
                  end

                  it 'logs the job email initiated analytic' do
                    expect(analytics).to have_received(
                      :idv_in_person_usps_proofing_results_job_email_initiated,
                    ).with(
                      enrollment_code: enrollment.enrollment_code,
                      timestamp: current_time,
                      wait_until: (enrollment.reload.status_check_completed_at +
                        in_person_results_delay_in_hours.hour),
                      service_provider: enrollment.issuer,
                      email_type: 'Failed fraud suspected',
                      job_name: described_class.name,
                    )
                  end

                  it 'logs the job completed analytic' do
                    expect(analytics).to have_received(
                      :idv_in_person_usps_proofing_results_job_completed,
                    ).with(
                      **default_job_completion_analytics,
                      enrollments_checked: 1,
                      enrollments_failed: 1,
                    )
                  end
                end
              end

              context 'when the USPS proofing results has an unsupported status' do
                before do
                  response_body[:status] = 'Unsupported'
                  stub_request_proofing_results(status_code: 200, body: response_body)
                  allow(analytics).to receive(
                    :idv_in_person_usps_proofing_results_job_exception,
                  )
                  subject.perform(current_time)
                end

                it 'logs the job started analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_started,
                  ).with(
                    enrollments_count: 1,
                    reprocess_delay_minutes: 5,
                    job_name: described_class.name,
                  )
                end

                it 'updates the enrollment status check timestamps' do
                  expect(enrollment.reload).to have_attributes(
                    status_check_attempted_at: current_time,
                    last_batch_claimed_at: current_time,
                  )
                end

                it 'logs the job exception analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_exception,
                  ).with(
                    **enrollment_analytics,
                    minutes_to_completion: nil,
                    **response_analytics,
                    reason: 'Unsupported status',
                    job_name: described_class.name,
                  )
                end

                it 'logs the job completed analytic' do
                  expect(analytics).to have_received(
                    :idv_in_person_usps_proofing_results_job_completed,
                  ).with(
                    **default_job_completion_analytics,
                    enrollments_checked: 1,
                    enrollments_errored: 1,
                    percent_enrollments_errored: 100.0,
                  )
                end
              end
            end

            context 'when notifications are not configured' do
              before do
                allow(IdentityConfig.store).to receive(
                  :in_person_send_proofing_notifications_enabled,
                ).and_return(nil)
              end

              context 'when the USPS proofing results has a passed status' do
                before do
                  stub_request_proofing_results(status_code: 200, body: response_body)
                  allow(analytics).to receive(
                    :idv_in_person_usps_proofing_results_job_enrollment_updated,
                  )
                  allow(analytics).to receive(
                    :idv_in_person_usps_proofing_results_job_email_initiated,
                  )
                  allow(user_mailer).to receive(:in_person_verified).and_return(mail_deliverer)
                  subject.perform(current_time)
                end

                it 'does not send a proofing sms notification' do
                  expect(send_proofing_notification_job).not_to have_received(
                    :perform_later,
                  ).with(enrollment.id)
                end
              end
            end

            context 'when the results delay is configured to be negative time' do
              before do
                allow(IdentityConfig.store).to receive(:in_person_results_delay_in_hours)
                  .and_return(-1)
              end

              context 'when the USPS proofing results has a passed status' do
                before do
                  stub_request_proofing_results(status_code: 200, body: response_body)
                  allow(analytics).to receive(
                    :idv_in_person_usps_proofing_results_job_enrollment_updated,
                  )
                  allow(analytics).to receive(
                    :idv_in_person_usps_proofing_results_job_email_initiated,
                  )
                  allow(user_mailer).to receive(:in_person_verified).and_return(mail_deliverer)
                  subject.perform(current_time)
                end

                it 'sends the in person verified email without delay' do
                  expect(user_mailer).to have_received(:in_person_verified).with(
                    enrollment: enrollment,
                    visited_location_name: visited_location_name,
                  )
                  expect(mail_deliverer).to have_received(:deliver_later).with(no_args)
                end
              end
            end

            context 'when the results delay is not configured' do
              before do
                allow(IdentityConfig.store).to receive(:in_person_results_delay_in_hours)
                  .and_return(nil)
              end

              context 'when the USPS proofing results has a passed status' do
                before do
                  stub_request_proofing_results(status_code: 200, body: response_body)
                  allow(analytics).to receive(
                    :idv_in_person_usps_proofing_results_job_enrollment_updated,
                  )
                  allow(analytics).to receive(
                    :idv_in_person_usps_proofing_results_job_email_initiated,
                  )
                  allow(user_mailer).to receive(:in_person_verified).and_return(mail_deliverer)
                  subject.perform(current_time)
                end

                it 'sends the in person verified email with a default 1 hour delay' do
                  expect(user_mailer).to have_received(:in_person_verified).with(
                    enrollment: enrollment,
                    visited_location_name: visited_location_name,
                  )
                  expect(mail_deliverer).to have_received(:deliver_later).with(
                    queue: :intentionally_delayed,
                    wait_until: (enrollment.reload.status_check_completed_at + 1.hour),
                  )
                end
              end
            end
          end
        end

        context 'when the enrollment has a profile with a deactivation reason' do
          context 'when the profile deactivation reason is "encryption_error"' do
            let(:deactivation_reason) { 'encryption_error' }

            before do
              enrollment.profile.update(deactivation_reason: deactivation_reason)
              allow(analytics).to receive(
                :idv_in_person_usps_proofing_results_job_enrollment_updated,
              )
              subject.perform(current_time)
            end

            it 'logs the job started analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_started,
              ).with(
                enrollments_count: 1,
                reprocess_delay_minutes: 5,
                job_name: described_class.name,
              )
            end

            it 'logs the job enrollment updated analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_enrollment_updated,
              ).with(
                **enrollment_analytics,
                response_present: false,
                passed: false,
                reason: "Profile has a deactivation reason of #{deactivation_reason}",
                job_name: described_class.name,
                tmx_status: nil,
                profile_age_in_seconds: enrollment.profile&.profile_age_in_seconds,
                enhanced_ipp: false,
              )
            end

            it 'cancels the enrollment' do
              expect(enrollment.reload).to have_attributes(
                status: 'cancelled',
              )
            end

            it "deactivates the enrollment's profile" do
              expect(enrollment.reload.profile).to have_attributes(
                active: false,
                deactivation_reason: 'encryption_error',
                in_person_verification_pending_at: nil,
              )
            end

            it 'logs the job completed analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_completed,
              ).with(
                **default_job_completion_analytics,
                enrollments_checked: 1,
                enrollments_cancelled: 1,
              )
            end
          end

          context 'when the deactivation reason is "password_reset"' do
            let(:deactivation_reason) { 'password_reset' }
            let(:in_person_verification_pending_at) do
              enrollment.profile.in_person_verification_pending_at
            end

            before do
              enrollment.profile.update(deactivation_reason: deactivation_reason)
              allow(InPersonEnrollment).to receive(:needs_usps_status_check).and_return(
                InPersonEnrollment.where(id: enrollment.id),
              )
              allow(analytics).to receive(
                :idv_in_person_usps_proofing_results_job_enrollment_skipped,
              )
              stub_request_passed_proofing_results
              allow(analytics).to receive(
                :idv_in_person_usps_proofing_results_job_enrollment_incomplete,
              )
              subject.perform(current_time)
            end

            it 'logs the job started analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_started,
              ).with(
                enrollments_count: 1,
                reprocess_delay_minutes: 5,
                job_name: described_class.name,
              )
            end

            it 'logs the job enrollment skipped analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_enrollment_skipped,
              ).with(
                **enrollment_analytics,
                minutes_to_completion: nil,
                reason: "Profile has a deactivation reason of #{deactivation_reason}",
                job_name: described_class.name,
              )
            end

            it 'does not cancel the enrollment' do
              expect(enrollment.reload).to have_attributes(
                status: 'pending',
              )
            end

            it "does not update the enrollment's profile" do
              expect(enrollment.reload.profile).to have_attributes(
                active: false,
                deactivation_reason:,
                in_person_verification_pending_at:,
              )
            end

            it 'logs the job completed analytic' do
              expect(analytics).to have_received(
                :idv_in_person_usps_proofing_results_job_completed,
              ).with(
                **default_job_completion_analytics,
                enrollments_checked: 1,
                enrollments_skipped: 1,
              )
            end
          end
        end

        context 'when multiple pending InPersonEnrollments exist' do
          let(:enrollments) do
            [
              create(:in_person_enrollment, :pending, :with_notification_phone_configuration),
              create(:in_person_enrollment, :pending, :with_notification_phone_configuration),
              create(:in_person_enrollment, :pending, :with_notification_phone_configuration),
              create(:in_person_enrollment, :pending, :with_notification_phone_configuration),
              create(:in_person_enrollment, :pending, :with_notification_phone_configuration),
              create(:in_person_enrollment, :pending, :with_notification_phone_configuration),
            ]
          end

          before do
            stub_request_proofing_results_with_responses(
              request_failed_proofing_results_args,
              request_in_progress_proofing_results_args,
              request_passed_proofing_results_args,
              { status: 500 },
              request_expired_enhanced_ipp_results_args,
            ).and_raise(Faraday::TimeoutError)
            allow(InPersonEnrollment).to receive(:needs_usps_status_check).and_return(
              InPersonEnrollment.where(id: enrollments.map(&:id)),
            )
            allow(analytics).to receive(:idv_in_person_usps_proofing_results_job_exception)
            allow(analytics).to receive(:idv_in_person_usps_proofing_results_job_enrollment_updated)
            allow(analytics).to receive(:idv_in_person_usps_proofing_results_job_email_initiated)
            allow(analytics).to receive(
              :idv_in_person_usps_proofing_results_job_enrollment_incomplete,
            )
            allow(analytics).to receive(
              :idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated,
            )
            allow(analytics).to receive(
              :idv_in_person_usps_proofing_results_job_unexpected_response,
            )
            allow(user_mailer).to receive(:in_person_failed).and_return(mail_deliverer)
            allow(user_mailer).to receive(:in_person_verified).and_return(mail_deliverer)
            allow(user_mailer).to receive(:in_person_deadline_passed).and_return(mail_deliverer)
            allow(UserMailer).to receive(:with).with(
              user: anything, email_address: anything,
            ).and_return(user_mailer)
            allow(subject).to receive(:sleep).and_return(true)
            subject.perform(current_time)
          end

          it 'logs the job started analytic' do
            expect(analytics).to have_received(
              :idv_in_person_usps_proofing_results_job_started,
            ).with(
              enrollments_count: 6,
              reprocess_delay_minutes: 5,
              job_name: described_class.name,
            )
          end

          it 'sleeps in between each pending enrollment' do
            expect(subject).to have_received(:sleep).exactly(5).times
          end

          it 'logs the job completed analytic' do
            expect(analytics).to have_received(
              :idv_in_person_usps_proofing_results_job_completed,
            ).with(
              **default_job_completion_analytics,
              enrollments_checked: 6,
              enrollments_passed: 1,
              enrollments_in_progress: 1,
              enrollments_expired: 1,
              enrollments_failed: 1,
              enrollments_errored: 1,
              enrollments_network_error: 1,
              percent_enrollments_errored: 16.67,
              percent_enrollments_network_error: 16.67,
            )
          end
        end
      end

      context 'when no pending InPersonEnrollments exist' do
        before do
          subject.perform(current_time)
        end

        it 'logs the job started analytic' do
          expect(analytics).to have_received(:idv_in_person_usps_proofing_results_job_started).with(
            enrollments_count: 0,
            reprocess_delay_minutes: 5,
            job_name: described_class.name,
          )
        end

        it 'logs the job completed analytic' do
          expect(analytics).to have_received(
            :idv_in_person_usps_proofing_results_job_completed,
          ).with(
            **default_job_completion_analytics,
          )
        end
      end
    end
  end
end
