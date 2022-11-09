require 'rails_helper'

RSpec.describe InPerson::EmailReminderJob do
  let(:job) { InPerson::EmailReminderJob.new }
  let(:early_benchmark) { 11 }
  let(:late_benchmark) { 4 }
  let(:final_benchmark) { 1 }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(IdentityConfig.store).to receive(:email_reminder_early_benchmark).
      and_return(early_benchmark)

    allow(IdentityConfig.store).to receive(:email_reminder_late_benchmark).
      and_return(late_benchmark)

    puts "job: #{job.pretty_inspect}"
  end

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

  describe '#perform' do
    it 'checks enrollments' do
    end

    context 'late email reminder' do
      let(:second_set_enrollments) {[pending_enrollment_needing_late_reminder]}
      it 'queues emails for enrollments that need the late email reminder sent' do
        user = pending_enrollment_needing_late_reminder.user
        freeze_time do
          expect do
            late_benchmark = Time.zone.now - 26.days
            final_benchmark = Time.zone.now - 29.days
            allow(InPersonEnrollment).to receive(:needs_late_email_reminder).
              with(late_benchmark, final_benchmark).
              and_return(second_set_enrollments)
              expect(second_set_enrollments[0].enrollment_code).to eq(pending_enrollment_needing_late_reminder.enrollment_code)
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

            early_benchmark = Time.zone.now - 19.days
            late_benchmark = Time.zone.now - 26.days

            allow(InPersonEnrollment).to receive(:needs_early_email_reminder).
              with(early_benchmark, late_benchmark).
              and_return(first_set_enrollments)

              job.perform(Time.zone.now)
              #  binding.pry
          end.to have_enqueued_mail(UserMailer, :in_person_ready_to_verify_reminder).with(
            params: { user: user, email_address: user.email_addresses.first },
            args: [{ enrollment: pending_enrollment_needing_early_reminder }],
          )
        end
      end
    end
  end
end
