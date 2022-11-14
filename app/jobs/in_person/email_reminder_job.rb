module InPerson
  class EmailReminderJob < ApplicationJob
    queue_as :low

    include GoodJob::ActiveJobExtensions::Concurrency

    discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError

    def perform(_now)
      # final reminder job done first in case of job failure
      in_person_email_reminder_late_benchmark_in_days =
        IdentityConfig.store.in_person_email_reminder_late_benchmark_in_days
      in_person_email_reminder_final_benchmark_in_days =
        IdentityConfig.store.in_person_email_reminder_final_benchmark_in_days
      late_benchmark = calculate_interval(in_person_email_reminder_late_benchmark_in_days)
      final_benchmark = calculate_interval(in_person_email_reminder_final_benchmark_in_days)

      second_set_enrollments = InPersonEnrollment.needs_late_email_reminder(
        late_benchmark,
        final_benchmark,
      )
      second_set_enrollments.each do |enrollment|
        send_reminder_email(enrollment.user, enrollment)
        enrollment.update!(late_reminder_sent: true)
      end

      in_person_email_reminder_early_benchmark_in_days =
        IdentityConfig.store.in_person_email_reminder_early_benchmark_in_days
      early_benchmark = calculate_interval(in_person_email_reminder_early_benchmark_in_days)

      first_set_enrollments = InPersonEnrollment.needs_early_email_reminder(
        early_benchmark,
        late_benchmark,
      )
      first_set_enrollments.each do |enrollment|
        send_reminder_email(enrollment.user, enrollment)
        enrollment.update!(early_reminder_sent: true)
      end
    end

    private

    def calculate_interval(benchmark)
      config = IdentityConfig.store.in_person_enrollment_validity_in_days.days
      (Time.zone.now - config) + benchmark.days
    end

    def send_reminder_email(user, enrollment)
      user.confirmed_email_addresses.each do |email_address|
        # rubocop:disable IdentityIdp/MailLaterLinter
        UserMailer.with(
          user: user,
          email_address: email_address,
        ).in_person_ready_to_verify_reminder(
          enrollment: enrollment,
        ).deliver_later
        # rubocop:enable IdentityIdp/MailLaterLinter
      end
    end
  end
end
