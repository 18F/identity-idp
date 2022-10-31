class EmailReminderJob < ApplicationJob
  # benchmark day to send email is 1 more than warning displayed in email
  REMINDER_BENCHMARKS = [4, 11]
  queue_as :low

  include GoodJob::ActiveJobExtensions::Concurrency

  discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError

  def perform(_now)
    email_reminder_first_check = IdentityConfig.store.email_reminder_first_check
    enrollments = InPersonEnrollment.needs_email_reminder(email_reminder_first_check)
    check_enrollments(enrollments)
  end

  private

  def check_enrollment_date(enrollment)
    REMINDER_BENCHMARKS.include?(enrollment.days_to_due_date)
  end

  def check_enrollments(enrollments)
    enrollments.each do |enrollment|
      send_reminder_email(enrollment.user, enrollment) if check_enrollment_date(enrollment)
    end
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
