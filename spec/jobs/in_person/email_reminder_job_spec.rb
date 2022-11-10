require 'rails_helper'

RSpec.describe InPerson::EmailReminderJob do
  let(:job) { InPerson::EmailReminderJob.new }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe '#perform' do

  let!(:passed_enrollment) { create(:in_person_enrollment, :passed) }
  let!(:failing_enrollment) { create(:in_person_enrollment, :failed) }
  let!(:expired_enrollment) { create(:in_person_enrollment, :expired) }
  let!(:pending_enrollment_needing_late_reminder) {create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now - 26.days)} 
  let!(:pending_enrollment_needing_early_reminder) {create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now - 19.days)}

  let!(:pending_enrollments) do
    [
      create(:in_person_enrollment, :pending, enrollment_established_at: Time.zone.now),
      create(:in_person_enrollment, :pending, created_at: Time.zone.now),
    ]
  end

    context 'late email reminder' do
       let(:second_set_enrollments) {[pending_enrollment_needing_late_reminder]}
      it 'queues emails for enrollments that need the late email reminder sent' do
        user = pending_enrollment_needing_late_reminder.user
        freeze_time do
          expect do
              job.perform(Time.zone.now)
          end.to have_enqueued_mail(UserMailer, :in_person_ready_to_verify_reminder).with(
            params: { user: user, email_address: user.email_addresses.first },
            args: [{ enrollment: pending_enrollment_needing_late_reminder }],
          )
           expect(pending_enrollment_needing_late_reminder.late_reminder_sent).to be_truthy
        end
      end
    end

    context 'early email reminder' do
       let(:first_set_enrollments) {[pending_enrollment_needing_early_reminder]}
      it 'queues emails for enrollments that need the early email reminder sent' do
        user = pending_enrollment_needing_early_reminder.user

        freeze_time do
          expect do
              job.perform(Time.zone.now)
          end.to have_enqueued_mail(UserMailer, :in_person_ready_to_verify_reminder).with(
            params: { user: user, email_address: user.email_addresses.first },
            args: [{ enrollment: pending_enrollment_needing_early_reminder }],
          )
          expect(pending_enrollment_needing_early_reminder.early_reminder_sent).to be_truthy
        end
      end
    end
  end
end
