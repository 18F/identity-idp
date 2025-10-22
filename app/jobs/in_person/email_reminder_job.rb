# frozen_string_literal: true

module InPerson
  class EmailReminderJob < ApplicationJob
    EMAIL_TYPE_LATE = 'late'

    queue_as :low

    def perform(_now)
      return true unless IdentityConfig.store.in_person_proofing_enabled

      enrollments = InPersonEnrollment.needs_late_email_reminder(
        reminder_start_date,
        reminder_end_date,
      )
      send_emails_for_enrollments(enrollments)
    end

    private

    def analytics(user: AnonymousUser.new)
      Analytics.new(user: user, request: nil, session: {}, sp: nil)
    end

    def send_emails_for_enrollments(enrollments)
      enrollments.each do |enrollment|
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
          email_type: EMAIL_TYPE_LATE,
          enrollment_id: enrollment.id,
        )
        enrollment.update!(late_reminder_sent: true)
      end
    end

    def calculate_reminder_date(offset)
      validity_days = IdentityConfig.store.in_person_enrollment_validity_in_days.days
      (Time.zone.now - validity_days) + offset.days
    end

    def reminder_start_date
      calculate_reminder_date(IdentityConfig.store.in_person_email_reminder_late_benchmark_in_days)
    end

    def reminder_end_date
      calculate_reminder_date(IdentityConfig.store.in_person_email_reminder_final_benchmark_in_days)
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
