module InPerson
  class EmailReminderJob < ApplicationJob
    EMAIL_TYPE_EARLY = 'early'.freeze
    EMAIL_TYPE_LATE = 'late'.freeze

    queue_as :low

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: 'in_person_email_reminder_job',
    )

    discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError

    def perform(_now)
      return true unless IdentityConfig.store.in_person_proofing_enabled

      # send late emails first in case of job failure
      late_enrollments = InPersonEnrollment.needs_late_email_reminder(
        late_benchmark,
        final_benchmark,
      )
      send_emails_for_enrollments(enrollments: late_enrollments, email_type: EMAIL_TYPE_LATE)

      early_enrollments = InPersonEnrollment.needs_early_email_reminder(
        early_benchmark,
        late_benchmark,
      )
      send_emails_for_enrollments(enrollments: early_enrollments, email_type: EMAIL_TYPE_EARLY)
    end

    private

    def analytics(user: AnonymousUser.new)
      Analytics.new(user: user, request: nil, session: {}, sp: nil)
    end

    def send_emails_for_enrollments(enrollments:, email_type:)
      enrollments.each do |enrollment|
        begin
          send_reminder_email(enrollment.user, enrollment)
        rescue StandardError => err
          NewRelic::Agent.notice_error(err)
          analytics(user: enrollment.user).idv_in_person_email_reminder_job_exception(
            enrollment_id: enrollment.id,
            exception_class: err.class.to_s,
            exception_message: err.message,
          )
        else
          analytics(user: enrollment.user).idv_in_person_email_reminder_job_email_initiated(
            email_type: email_type,
            enrollment_id: enrollment.id,
          )
          enrollment.update!({ "#{email_type}_reminder_sent": true })
        end
      end
    end

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
