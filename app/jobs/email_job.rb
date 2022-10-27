class EmailJob < ApplicationJob
  REMINDER_BENCHMARKS = [3, 10]
  queue_as :low

  include GoodJob::ActiveJobExtensions::Concurrency

  # good_job_control_concurrency_with(
  #   total_limit: 1,
  #   key: -> { 'email_job' },
  # )

  discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError

  def check_enrollment_date(enrollment)
    REMINDER_BENCHMARKS.include?(enrollment.days_to_due_date)
  end

  def check_enrollments(enrollments)
    enrollments.each do |enrollment|
      if check_enrollment_date(enrollment) do
        send_reminder_email(enrollment.user, enrollment)
      end
  end
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
      ).deliver_now(**mail_delivery_params)
      # rubocop:enable IdentityIdp/MailLaterLinter
    end
  end

  def perform(_now)
    # do a test daily
    # check inpersonenrollment days_to_due_date
    # if at our benchmark then send email
    # time in needs_usps_status_check needs time equiv. to day
    # probably update to needs_pending_check?
    enrollments = InPersonEnrollment.needs_usps_status_check(2.minutes.ago)
    check_enrollments(enrollments)
  end
end
