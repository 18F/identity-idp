# frozen_string_literal: true

module InPerson
  class SendProofingNotificationJob < ApplicationJob
    # @param [InPersonEnrollment] enrollment
    def perform(enrollment)
      return true if IdentityConfig.store.in_person_proofing_enabled.blank? ||
                     IdentityConfig.store.in_person_send_proofing_notifications_enabled.blank?

      # skip
      if !enrollment.notification_phone_configuration.present? || (!enrollment.passed? && !enrollment.failed?)
        # log event
        analytics(user: enrollment.user).
          idv_in_person_usps_proofing_results_notification_job_skipped(
            **enrollment_analytics_attributes(enrollment, complete: false),
            job_name: self.class.name,
          )
        return true
      end
      analytics(user: enrollment.user).
        idv_in_person_usps_proofing_results_notification_job_started
      if enrollment.passed? || enrollment.failed?
        # send notification and log result
        phone = enrollment.notification_phone_configuration.formatted_phone
        message = notification_message(status: enrollment.passed? ? :success : :failure)
        response = Telephony.send_notification(
          to: phone, message: message,
          country_code: Phonelib.parse(phone).country
        )
        handle_telephony_result(enrollment: enrollment, telephony_result: response)
        if response.success?
          # if notification sent successful
          enrollment.update(
            notification_sent_at: Time.zone.now,
          )
          # delete notification phone configuraiton if success
          enrollment.notification_phone_configuration.destroy!
        end
      end
      analytics(user: enrollment.user).
        idv_in_person_usps_proofing_results_notification_job_completed
      return true
    end

    private

    def handle_telephony_result(enrollment:, telephony_result:)
      if telephony_result.success?
        analytics(user: enrollment.user).
          idv_in_person_usps_proofing_results_notification_sent_success(
            **enrollment_analytics_attributes(enrollment, complete: false),
            job_name: self.class.name,
          )
        # log success
      elsif telephony_result.error.is_a?(Telephony::OptOutError)
        analytics(user: enrollment.user).
          idv_in_person_usps_proofing_results_notification_sent_failure(
            **enrollment_analytics_attributes(enrollment, complete: false),
            job_name: self.class.name, reason: 'Optout'
          )
        # clear message from https://github.com/18F/identity-idp/blob/7ad3feab24f6f9e0e45224d9e9be9458c0a6a648/app/controllers/users/phones_controller.rb#L40
        PhoneNumberOptOut.mark_opted_out(phone_to_deliver_to)
        # redirect_to login_two_factor_sms_opt_in_path(opt_out_uuid: opt_out)
      else
        analytics(user: enrollment.user).
          idv_in_person_usps_proofing_results_notification_sent_failure(
            **enrollment_analytics_attributes(enrollment, complete: false),
            job_name: self.class.name, reason: telephony_result.error
          )
      end
    end

    def notification_message(status:)
      'test'
    end

    def analytics(user: AnonymousUser.new)
      Analytics.new(user: user, request: nil, session: {}, sp: nil)
    end

    def enrollment_analytics_attributes(enrollment, complete:)
      {
        enrollment_code: enrollment.enrollment_code,
        enrollment_id: enrollment.id,
        minutes_since_last_status_check: enrollment.minutes_since_last_status_check,
        minutes_since_last_status_check_completed:
          enrollment.minutes_since_last_status_check_completed,
        minutes_since_last_status_update: enrollment.minutes_since_last_status_update,
        minutes_since_established: enrollment.minutes_since_established,
        minutes_to_completion: complete ? enrollment.minutes_since_established : nil,
        issuer: enrollment.issuer,
      }
    end
  end
end
