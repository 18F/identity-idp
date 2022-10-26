class EmailJob < ApplicationJob
    REMINDER_BENCHMARKS = [ 3, 10 ]
    queue_as :low
  
    include GoodJob::ActiveJobExtensions::Concurrency
  
    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { 'email_job' },
    )
  
    discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError
  
    check_enrollment_date(enrollment)
        REMINDER_BENCHMARKS.include?(enrollment.days_to_due_date)
    end

    def send_reminder_email(user, enrollment)
        user.confirmed_email_addresses.each do |email_address|
        # rubocop:disable IdentityIdp/MailLaterLinter
        UserMailer.with(user: user, email_address: email_address).in_person_ready_to_verify_reminder(
            enrollment: enrollment,
        ).deliver_now(**mail_delivery_params)
        # rubocop:enable IdentityIdp/MailLaterLinter
        end
    end

    # Enqueue a test letter every day, but only upload letters on working weekdays
    def perform(date)
        # do a test daily
        # check inpersonenrollment days_to_due_date
        # if at our benchmark then send email 
      GpoDailyTestSender.new.run
  
      GpoConfirmationUploader.new.run unless CalendarService.weekend_or_holiday?(date)
    end
  end
  