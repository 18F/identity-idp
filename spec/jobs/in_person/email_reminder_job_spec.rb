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
      it 'queues emails for enrollments that need the late email reminder sent' do
        #  binding.pry
        user = pending_enrollment_needing_late_reminder.user
        freeze_time do
          expect do
            late_benchmark = Time.zone.now - 26.days
            final_benchmark = Time.zone.now - 29.days
            #  this does return the correct item
            allow(InPersonEnrollment).to receive(:needs_late_email_reminder).
              with(late_benchmark, final_benchmark).
              and_return([pending_enrollment_needing_late_reminder])
              # expect(:second_set_enrollments).to eq(pending_enrollment_needing_late_reminder)
            job.perform(Time.zone.now)
            puts " adapter = #{ActiveJob::Base.queue_adapter.pretty_inspect}"
            puts "jobs = #{ActiveJob::Base.queue_adapter.enqueued_jobs}"
          end.to have_enqueued_mail(UserMailer, :in_person_ready_to_verify_reminder).with(
            params: { user: user, email_address: user.email_addresses.first },
            args: [{ enrollment: pending_enrollment_needing_late_reminder }],
          ).at(Time.zone.now)
        end
      end
    end

    expects array but isnt getting it 
    context 'early email reminder' do
      it 'queues emails for enrollments that need the early email reminder sent' do
        user = pending_enrollment_needing_early_reminder.user

        freeze_time do
          expect do

            early_benchmark = Time.zone.now - 19.days
            late_benchmark = Time.zone.now - 26.days

            allow(InPersonEnrollment).to receive(:needs_early_email_reminder).
              with(early_benchmark, late_benchmark).
              and_return([pending_enrollment_needing_early_reminder])
              job.perform(Time.zone.now)
          end.to have_enqueued_mail(UserMailer, :in_person_ready_to_verify_reminder).with(
            params: { user: user, email_address: user.email_addresses.first },
            args: [{ enrollment: pending_enrollment_needing_early_reminder }],
          ).at(Time.zone.now)
        end
      end
    end
  end
end
