module InPerson
  class EmailReminderJob < ApplicationJob
    queue_as :low

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: 'in_person_email_reminder_job',
    )

    discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError

    def perform(_now)
      return true unless IdentityConfig.store.in_person_proofing_enabled

      # final reminder job done first in case of job failure
      second_set_enrollments = InPersonEnrollment.needs_late_email_reminder(
        late_benchmark,
        final_benchmark,
      )
      second_set_enrollments.each do |enrollment|
        send_reminder_email(enrollment.user, enrollment)
        enrollment.update!(late_reminder_sent: true)
      end

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
      days_until_expired = IdentityConfig.store.in_person_enrollment_validity_in_days.days
      (Time.zone.now - days_until_expired) + benchmark.days
    end

    def early_benchmark
      calculate_interval(IdentityConfig.store.in_person_email_reminder_early_benchmark_in_days)
    end

    def late_benchmark
      calculate_interval(IdentityConfig.store.in_person_email_reminder_late_benchmark_in_days)
    end

    def final_benchmark
      calculate_interval(IdentityConfig.store.in_person_email_reminder_final_benchmark_in_days)
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
