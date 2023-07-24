# frozen_string_literal: true

module InPerson
  class SendProofingNotificationJob < ApplicationJob
    # @param [Number] enrollment_id primary key of the enrollment
    def perform(enrollment_id)
      return unless IdentityConfig.store.in_person_proofing_enabled &&
                    IdentityConfig.store.in_person_send_proofing_notifications_enabled

      enrollment = InPersonEnrollment.find_by(
        { id: enrollment_id },
        include: [:notification_phone_configuration, :user],
      )

      if enrollment.nil? || !enrollment.eligible_for_notification?
        analytics(user: enrollment&.user || AnonymousUser.new).
          idv_in_person_usps_proofing_results_notification_job_skipped(
            enrollment_code: enrollment&.enrollment_code,
            enrollment_id: enrollment&.id,
          )
        return
      end

      analytics(user: enrollment.user).
        idv_in_person_usps_proofing_results_notification_job_started(
          enrollment_code: enrollment.enrollment_code,
          enrollment_id: enrollment.id,
        )
      if enrollment.expired?
        # no sending message for expired status
        enrollment.notification_phone_configuration&.destroy
        log_job_completed(enrollment: enrollment)
        return
      end

      # send notification and log result when success or failed
      phone = enrollment.notification_phone_configuration.formatted_phone
      message = notification_message(enrollment: enrollment)
      response = Telephony.send_notification(
        to: phone, message: message,
        country_code: Phonelib.parse(phone).country
      )
      handle_telephony_response(enrollment: enrollment, phone: phone, telephony_response: response)

      enrollment.update(notification_sent_at: Time.zone.now) if response.success?

      log_job_completed(enrollment: enrollment)
    end

    private

    def log_job_completed(enrollment:)
      analytics(user: enrollment.user).
        idv_in_person_usps_proofing_results_notification_job_completed(
          enrollment_code: enrollment.enrollment_code, enrollment_id: enrollment.id,
        )
    end

    def handle_telephony_response(enrollment:, phone:, telephony_response:)
      analytics(user: enrollment.user).
        idv_in_person_usps_proofing_results_notification_sent_attempted(
          success: telephony_response.success?,
          enrollment_code: enrollment.enrollment_code,
          enrollment_id: enrollment.id,
          telephony_response: telephony_response.to_h,
        )
      if telephony_response.error&.is_a?(Telephony::OptOutError)
        PhoneNumberOptOut.mark_opted_out(phone)
      end
    end

    def notification_message(enrollment:)
      proof_date = enrollment.proofed_at ? I18n.l(enrollment.proofed_at, format: :sms_date) : 'NA'
      I18n.t(
        'telephony.confirmation_ipp_enrollment_result.sms',
        app_name: APP_NAME,
        proof_date: proof_date,
      )
    end

    def analytics(user:)
      Analytics.new(user: user, request: nil, session: {}, sp: nil)
    end
  end
end
