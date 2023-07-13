# frozen_string_literal: true

module InPerson
  class SendProofingNotificationJob < ApplicationJob
    # @param [Number] enrollment_id primary key of the enrollment
    def perform(enrollment_id)
      return if IdentityConfig.store.in_person_proofing_enabled.blank? ||
                     IdentityConfig.store.in_person_send_proofing_notifications_enabled.blank?
      enrollment = InPersonEnrollment.find(
        enrollment_id,
        include: [:notification_phone_configuration, :user],
      )
      # skip
      if !enrollment.notification_phone_configuration.present? ||
         (!enrollment.passed? && !enrollment.failed?)
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
      if enrollment.passed? || enrollment.failed?
        # send notification and log result
        phone = enrollment.notification_phone_configuration.formatted_phone
        message = notification_message(enrollment: enrollment)
        response = Telephony.send_notification(
          to: phone, message: message,
          country_code: Phonelib.parse(phone).country
        )
        handle_telephony_result(enrollment: enrollment, phone: phone, telephony_result: response)
        if response.success?
          # if notification sent successful
          enrollment.update(
            notification_sent_at: Time.zone.now,
          )
          # delete notification phone configuraiton if success
          enrollment.notification_phone_configuration.destroy!
        end
      end
    ensure
      unless enrollment.present?
        enrollment = InPersonEnrollment.find(
          enrollment_id,
          include: [:notification_phone_configuration,
                    :user],
        )
      end
      analytics(user: enrollment.user).
        idv_in_person_usps_proofing_results_notification_job_completed(
          enrollment_code: enrollment.enrollment_code, enrollment_id: enrollment.id,
        )
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
        # log success
      elsif telephony_result.error.is_a?(Telephony::OptOutError)
        analytics(user: enrollment.user).
          idv_in_person_usps_proofing_results_notification_sent_attempted(
            success: false,
            enrollment_code: enrollment.enrollment_code,
            enrollment_id: enrollment.id,
            telephony_result: telephony_result,
          )
        PhoneNumberOptOut.mark_opted_out(phone)
      else
        analytics(user: enrollment.user).
          idv_in_person_usps_proofing_results_notification_sent_attempted(
            success: false,
            enrollment_code: enrollment.enrollment_code,
            enrollment_id: enrollment.id,
            telephony_result: telephony_result,
          )
      end
    end

    def notification_message(enrollment:)
      proof_date = enrollment.proofed_at ? enrollment.proofed_at.strftime('%m/%d/%Y') : 'NA'
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
