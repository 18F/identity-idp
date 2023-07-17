# frozen_string_literal: true

module InPerson
  class SendProofingNotificationJob < ApplicationJob
    # @param [Number] enrollment_id primary key of the enrollment
    def perform(enrollment_id)
      return unless IdentityConfig.store.in_person_proofing_enabled &&
                    IdentityConfig.store.in_person_send_proofing_notifications_enabled
      begin
        enrollment = InPersonEnrollment.find_by(
          { id: enrollment_id },
          include: [:notification_phone_configuration, :user],
        )
        return unless enrollment
        # skip when enrollment status not success/failed/expired and no phone configured
        if enrollment.skip_notification_sent_at_set?
          # log event
          analytics(user: enrollment.user).
            idv_in_person_usps_proofing_results_notification_job_skipped(
              enrollment_code: enrollment.enrollment_code,
              enrollment_id: enrollment.id,
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
          return
        end

        # only send sms when success or failed
        # send notification and log result
        phone = enrollment.notification_phone_configuration.formatted_phone
        message = notification_message(enrollment: enrollment)
        response = Telephony.send_notification(
          to: phone, message: message,
          country_code: Phonelib.parse(phone).country
        )
        handle_telephony_result(enrollment: enrollment, phone: phone, telephony_result: response)
        # if notification sent successful
        enrollment.update(notification_sent_at: Time.zone.now) if response.success?
      ensure
        Rails.logger.error("Unknown enrollment with id #{enrollment_id}") unless enrollment.present?
        analytics(user: enrollment.present? ? enrollment.user : AnonymousUser.new).
          idv_in_person_usps_proofing_results_notification_job_completed(
            enrollment_code: enrollment&.enrollment_code, enrollment_id: enrollment_id,
          )
      end
    end

    private

    def handle_telephony_result(enrollment:, phone:, telephony_result:)
      if telephony_result.success?
        analytics(user: enrollment.user).
          idv_in_person_usps_proofing_results_notification_sent_attempted(
            success: true,
            enrollment_code: enrollment.enrollment_code,
            enrollment_id: enrollment.id,
            telephony_result: telephony_result,
          )
      else
        analytics(user: enrollment.user).
          idv_in_person_usps_proofing_results_notification_sent_attempted(
            success: false,
            enrollment_code: enrollment.enrollment_code,
            enrollment_id: enrollment.id,
            telephony_result: telephony_result,
          )
        if telephony_result.error&.is_a?(Telephony::OptOutError)
          PhoneNumberOptOut.mark_opted_out(phone)
        end
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
