# frozen_string_literal: true
module InPerson
  class SendProofingNotificationAndDeletePhoneNumberJob < ApplicationJob
    # @param [InPersonEnrollment] enrollment
    def perform(enrollment)
      if !enrollment.notification_phone_configuration.present?
        #log event
        return true
      end

      # skip status not passed or failed
      if ! enrollment.passed? and ! enrollment.failed?
        #log event
        return true
      end

      if enrollment.passed? || enrollment.failed?
        #send notification and log result
        phone = enrollment.notification_phone_configuration.formatted_phone
        message = notification_message(status: enrollment.passed? ? :success : :failure)
        response = Telephony.send_notification(to: phone, message: message, country_code: Phonelib.parse(phone).country)
        if(response.success?)
          # if notification sent successful
          enrollment.update(
            notification_sent_at: Time.zone.now,
            )
        end
        handle_telephony_result(telephony_result: response)
        #delete notification phone configuraiton if success
        enrollment.notification_phone_configuration.destroy!
      end
    end

    private

    def handle_telephony_result(telephony_result:)
      # track_events(
      #   otp_delivery_preference: method,
      #   otp_delivery_selection_result: otp_delivery_selection_result,
      #   )
      if telephony_result.success?

        #log success
      elsif telephony_result.error.is_a?(Telephony::OptOutError)
        # clear message from https://github.com/18F/identity-idp/blob/7ad3feab24f6f9e0e45224d9e9be9458c0a6a648/app/controllers/users/phones_controller.rb#L40
        opt_out = PhoneNumberOptOut.mark_opted_out(phone_to_deliver_to)
        #redirect_to login_two_factor_sms_opt_in_path(opt_out_uuid: opt_out)
      else
        #invalid_phone_number(@telephony_result.error, action: action_name)
        # log invalid phone
      end
    end

    def notification_message(status:)

    end

  end
end
