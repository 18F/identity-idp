class EmailReminderJob < ApplicationJob
  # benchmark day to send email is 1 more than warning displayed in email
  REMINDER_BENCHMARKS = [4, 11]
  queue_as :low

  include GoodJob::ActiveJobExtensions::Concurrency

  discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError

  def perform(_now)

    # final reminder job done first in case of job failure
    # 4-2 days interval
    email_reminder_second_check = IdentityConfig.store.email_reminder_second_check
    email_reminder_final_check = IdentityConfig.store.email_reminder_final_check
    second_set_enrollments = InPersonEnrollment.needs_late_email_reminder(
      calculate_interval(email_reminder_second_check),
      calculate_interval(email_reminder_final_check),
    )
    second_set_enrollments.each do |enrollment|
      send_reminder_email(enrollment.user, enrollment)
      enrollment.update!(late_reminder_sent: true)
    end

    # 11-5 days is interval
    email_reminder_first_check = IdentityConfig.store.email_reminder_first_check
    first_set_enrollments = InPersonEnrollment.needs_early_email_reminder(
      calculate_interval(email_reminder_first_check),
      calculate_interval(email_reminder_second_check),
    )
    first_set_enrollments.each do |enrollment|
      send_reminder_email(enrollment.user, enrollment)
      enrollment.update!(early_reminder_sent: true)
    end
  end

  private

  def calculate_interval(benchmark)
    config = IdentityConfig.store.in_person_enrollment_validity_in_days.days
    reminder_email_timestamp = (Time.zone.now - config) + benchmark.days
  end

  def send_reminder_email(user, enrollment)
    user.confirmed_email_addresses.each do |email_address|
      # rubocop:disable IdentityIdp/MailLaterLinter
      UserMailer.with(
        user: user,
        email_address: email_address,
      ).in_person_ready_to_verify_reminder(
        enrollment: enrollment,
      ).deliver_now
      # rubocop:enable IdentityIdp/MailLaterLinter
    end
  end
end
