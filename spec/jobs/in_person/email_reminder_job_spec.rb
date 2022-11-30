require 'rails_helper'

RSpec.describe InPerson::EmailReminderJob do
  let(:job) { InPerson::EmailReminderJob.new }
  let(:job_analytics) { FakeAnalytics.new }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(job).to receive(:analytics).and_return(job_analytics)
  end

  describe '#perform' do
    context 'with many enrollments' do
      let!(:passed_enrollment) { create(:in_person_enrollment, :passed) }
      let!(:failing_enrollment) { create(:in_person_enrollment, :failed) }
      let!(:expired_enrollment) { create(:in_person_enrollment, :expired) }
      let!(:pending_enrollment_needing_late_reminder) do
        create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now - 26.days)
      end
      let!(:pending_enrollment_needing_early_reminder) do
        create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now - 19.days)
      end

      let!(:pending_enrollment_received_late_reminder) do
        create(
          :in_person_enrollment, :pending, enrollment_established_at: Time.zone.now - 26.days,
                                           late_reminder_sent: true
        )
      end
      let!(:pending_enrollment_received_early_reminder) do
        create(
          :in_person_enrollment, :pending, enrollment_established_at: Time.zone.now - 19.days,
                                           early_reminder_sent: true
        )
      end

      let!(:pending_enrollments) do
        [
          create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now),
          create(:in_person_enrollment, :pending, created_at: Time.zone.now),
        ]
      end

      context 'late email reminder' do
        it 'queues emails for enrollments that need the late email reminder sent' do
          user = pending_enrollment_needing_late_reminder.user
          expect do
            job.perform(Time.zone.now)
          end.to have_enqueued_mail(UserMailer, :in_person_ready_to_verify_reminder).with(
            params: { user: user, email_address: user.email_addresses.first },
            args: [{ enrollment: pending_enrollment_needing_late_reminder }],
          )
          pending_enrollment_needing_late_reminder.reload
          expect(pending_enrollment_needing_late_reminder.late_reminder_sent).to be_truthy
          expect(job_analytics).to have_logged_event(
            'InPerson::EmailReminderJob: Reminder email initiated',
            email_type: 'late',
            enrollment_id: pending_enrollment_needing_late_reminder.id,
          )
        end

        it 'does not queue emails for enrollments that had late email reminder sent' do
          user = pending_enrollment_received_late_reminder.user
          expect do
            job.perform(Time.zone.now)
          end.not_to have_enqueued_mail(UserMailer, :in_person_ready_to_verify_reminder).with(
            params: { user: user, email_address: user.email_addresses.first },
            args: [{ enrollment: pending_enrollment_received_late_reminder }],
          )
          expect(pending_enrollment_received_late_reminder.late_reminder_sent).to be_truthy
        end
      end

      context 'early email reminder' do
        it 'queues emails for enrollments that need the early email reminder sent' do
          user = pending_enrollment_needing_early_reminder.user
          expect do
            job.perform(Time.zone.now)
          end.to have_enqueued_mail(UserMailer, :in_person_ready_to_verify_reminder).with(
            params: { user: user, email_address: user.email_addresses.first },
            args: [{ enrollment: pending_enrollment_needing_early_reminder }],
          )
          pending_enrollment_needing_early_reminder.reload
          expect(pending_enrollment_needing_early_reminder.early_reminder_sent).to be_truthy
          expect(job_analytics).to have_logged_event(
            'InPerson::EmailReminderJob: Reminder email initiated',
            email_type: 'early',
            enrollment_id: pending_enrollment_needing_early_reminder.id,
          )
        end

        it 'does not queue emails for enrollments that had early email reminder sent' do
          user = pending_enrollment_received_early_reminder.user
          expect do
            job.perform(Time.zone.now)
          end.not_to have_enqueued_mail(UserMailer, :in_person_ready_to_verify_reminder).with(
            params: { user: user, email_address: user.email_addresses.first },
            args: [{ enrollment: pending_enrollment_received_early_reminder }],
          )
          expect(pending_enrollment_received_early_reminder.early_reminder_sent).to be_truthy
        end
      end
    end

    context 'with one eligible enrollment' do
      let!(:pending_enrollment_needing_late_reminder) do
        create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now - 26.days)
      end

      context 'an error is raised when sending an email' do
        let(:error_message) { 'A standard error happened' }
        let!(:error) { StandardError.new(error_message) }

        it 'it handles and logs the error' do
          allow(UserMailer).to receive(:with).once.and_raise(error)
          expect(NewRelic::Agent).to receive(:notice_error).with(error)
          job.perform(Time.zone.now)
          expect(job_analytics).to have_logged_event(
            'InPerson::EmailReminderJob: Exception raised when attempting to send reminder email',
            exception_message: error_message,
          )
        end
      end
    end
  end
end
