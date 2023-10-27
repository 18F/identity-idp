# frozen_string_literal: true

module InPerson
  class SendProofingNotificationJob < ApplicationJob
    include LocaleHelper

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
          idv_in_person_send_proofing_notification_job_skipped(
            enrollment_code: enrollment&.enrollment_code,
            enrollment_id: enrollment_id,
          )
        return
      end

      analytics(user: enrollment.user).
        idv_in_person_send_proofing_notification_job_started(
          enrollment_code: enrollment.enrollment_code,
          enrollment_id: enrollment.id,
        )

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
    rescue StandardError => err
      analytics(user: enrollment&.user || AnonymousUser.new).
        idv_in_person_send_proofing_notification_job_exception(
          enrollment_code: enrollment&.enrollment_code,
          enrollment_id: enrollment_id,
          exception_class: err.class.to_s,
          exception_message: err.message,
        )
    end

    private

    def log_job_completed(enrollment:)
      analytics(user: enrollment.user).
        idv_in_person_send_proofing_notification_job_completed(
          enrollment_code: enrollment.enrollment_code, enrollment_id: enrollment.id,
        )
    end

    def handle_telephony_response(enrollment:, phone:, telephony_response:)
      analytics(user: enrollment.user).
        idv_in_person_send_proofing_notification_attempted(
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
      with_user_locale(enrollment.user) do
        proof_date = I18n.l(enrollment.proofed_at, format: :sms_date)
        I18n.t(
          'telephony.confirmation_ipp_enrollment_result.sms',
          app_name: APP_NAME,
          proof_date: proof_date,
          contact_number: IdentityConfig.store.idv_contact_phone_number,
          reference_string: enrollment.enrollment_code,
        )
      end
    end

    def analytics(user:)
      Analytics.new(user: user, request: nil, session: {}, sp: nil)
    end
  end
end
