require 'rails_helper'

RSpec.describe InPerson::SendProofingNotificationJob do
  include Shoulda::Matchers::ActiveModel
  let(:job) { InPerson::SendProofingNotificationJob.new }
  let(:analytics) { FakeAnalytics.new }

  let(:passed_enrollment_without_notification) { create(:in_person_enrollment, :passed) }
  let(:passed_enrollment) do
    enrollment = create(:in_person_enrollment, :passed, :with_notification_phone_configuration)
    enrollment.proofed_at = Time.zone.now - 3.days
    enrollment
  end
  let(:failing_enrollment) do
    enrollment = create(:in_person_enrollment, :failed, :with_notification_phone_configuration)
    enrollment.proofed_at = Time.zone.now - 3.days
    enrollment
  end
  let(:expired_enrollment) do
    enrollment = create(:in_person_enrollment, :expired, :with_notification_phone_configuration)
    enrollment
  end
  let(:sms_success_response) do
    Telephony::Response.new(
      success: true,
      extra: { request_id: 'fake-message-request-id', message_id: 'fake-message-id' },
    )
  end
  let(:sms_opt_out_response) do
    Telephony::Response.new(
      success: false,
      extra: { request_id: 'fake-message-request-id', message_id: 'fake-message-id' },
      error: Telephony::OptOutError.new,
    )
  end
  let(:sms_failure_response) do
    Telephony::Response.new(
      success: false,
      extra: { request_id: 'fake-message-request-id', message_id: 'fake-message-id' },
      error: Telephony::DailyLimitReachedError.new,
    )
  end
  before do
    ActiveJob::Base.queue_adapter = :test
    allow(job).to receive(:analytics).and_return(analytics)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)
    allow(IdentityConfig.store).to receive(:in_person_send_proofing_notifications_enabled).
      and_return(in_person_send_proofing_notifications_enabled)
  end

  describe '#perform' do
    context 'in person proofing disabled' do
      let(:in_person_proofing_enabled) { false }
      let(:in_person_send_proofing_notifications_enabled) { true }
      it 'returns without doing anything' do
        expect(job).not_to receive(:poll)
        expect(job).not_to receive(:process_batch)
        job.perform(passed_enrollment.id)

        expect(analytics).not_to have_logged_event('SendProofingNotificationJob: job started')
        expect(analytics).not_to have_logged_event('SendProofingNotificationJob: job completed')
      end
    end
    context 'job disabled' do
      let(:in_person_proofing_enabled) { true }
      let(:in_person_send_proofing_notifications_enabled) { false }
      it 'returns without doing anything' do
        expect(job).not_to receive(:poll)
        expect(job).not_to receive(:process_batch)
        job.perform(passed_enrollment.id)
        expect(analytics).not_to have_logged_event('SendProofingNotificationJob: job started')
        expect(analytics).not_to have_logged_event('SendProofingNotificationJob: job completed')
      end
    end
    context 'ipp and job enabled' do
      let(:in_person_proofing_enabled) { true }
      let(:in_person_send_proofing_notifications_enabled) { true }
      context 'enrollment does not exist' do
        it 'returns without doing anything' do
          bad_id = (InPersonEnrollment.all.pluck(:id).max || 0) + 1
          job.perform(bad_id)
          expect(analytics).not_to have_logged_event('SendProofingNotificationJob: job started')
          expect(analytics).to have_logged_event('SendProofingNotificationJob: job skipped')
        end
      end
      context 'enrollment has an unsupported status' do
        it 'returns without doing anything' do
          job.perform(expired_enrollment.id)
          expect(analytics).not_to have_logged_event('SendProofingNotificationJob: job started')
          expect(analytics).to have_logged_event('SendProofingNotificationJob: job skipped')
        end
      end
      context 'without notification phone notification' do
        it 'returns without doing anything' do
          job.perform(passed_enrollment_without_notification.id)
          expect(analytics).not_to have_logged_event('SendProofingNotificationJob: job started')
          expect(analytics).to have_logged_event('SendProofingNotificationJob: job skipped')
        end
      end
      context 'with notification phone configuration' do
        it 'sends notification successfully when enrollment is successful and enrollment updated' do
          allow(Telephony).to receive(:send_notification).and_return(sms_success_response)

          freeze_time do
            now = Time.zone.now
            expect(passed_enrollment.reload.notification_sent_at).to be_nil

            job.perform(passed_enrollment.id)
            expect(analytics).to have_logged_event('SendProofingNotificationJob: job started')
            expect(analytics).to have_logged_event('SendProofingNotificationJob: job completed')
            expect(analytics).to have_logged_event(
              'SendProofingNotificationJob: in person notification SMS send attempted'
            )
            expect(passed_enrollment.reload.notification_sent_at).to eq(now)
            expect(passed_enrollment.reload.notification_phone_configuration).to be_nil
          end
        end
        it 'sends notification successfully when enrollment failed' do
          allow(Telephony).to receive(:send_notification).and_return(sms_success_response)

          freeze_time do
            now = Time.zone.now
            job.perform(failing_enrollment.id)
            expect(analytics).to have_logged_event('SendProofingNotificationJob: job started')
            expect(analytics).to have_logged_event('SendProofingNotificationJob: job completed')
            expect(analytics).to have_logged_event(
              'SendProofingNotificationJob: in person notification SMS send attempted'
            )
            expect(failing_enrollment.reload.notification_sent_at).to eq(now)
            expect(failing_enrollment.reload.notification_phone_configuration).to be_nil
          end
        end
      end
      context 'when failed to send notification' do
        it 'logs sms send failure when number is opt out and enrollment not updated' do
          allow(Telephony).to receive(:send_notification).and_return(sms_opt_out_response)

          job.perform(passed_enrollment.id)
          expect(analytics).to have_logged_event(
            'SendProofingNotificationJob: in person notification SMS send attempted'
          )
          expect(passed_enrollment.reload.notification_sent_at).to be_nil
        end
        it 'logs sms send failure for delivery failure' do
          allow(Telephony).to receive(:send_notification).and_return(sms_failure_response)

          job.perform(passed_enrollment.id)
          expect(analytics).to have_logged_event(
            'SendProofingNotificationJob: in person notification SMS send attempted'
          )
          expect(passed_enrollment.reload.notification_sent_at).to be_nil
        end
      end
      context 'when an exception is raised' do
        it 'logs the exception details' do
          allow(InPersonEnrollment).
            to receive(:find_by).
            and_raise(ActiveRecord::DatabaseConnectionError)

          job.perform(passed_enrollment.id)

          expect(analytics).to have_logged_event(
            'SendProofingNotificationJob: exception raised',
            enrollment_code: nil,
            enrollment_id: passed_enrollment.id,
            exception_class: 'ActiveRecord::DatabaseConnectionError',
            exception_message: 'Database connection error',
          )
        end
      end
    end
  end
end
