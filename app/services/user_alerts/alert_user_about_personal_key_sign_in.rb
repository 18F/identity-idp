module UserAlerts
  class AlertUserAboutPersonalKeySignIn
    # @return [FormResponse]
    def self.call(user, disavowal_token)
      emails = user.confirmed_email_addresses.map do |email_address|
        UserMailer.with(user: user, email_address: email_address).personal_key_sign_in(
          disavowal_token: disavowal_token,
        ).deliver_now_or_later
      end
      telephony_responses = MfaContext.new(user).phone_configurations.map do |phone_configuration|
        phone = phone_configuration.phone
        Telephony.send_personal_key_sign_in_notice(
          to: phone,
          country_code: Phonelib.parse(phone).country,
        )
      end
      form_response(emails: emails, telephony_responses: telephony_responses)
    end

    def self.form_response(emails:, telephony_responses:)
      FormResponse.new(
        success: true,
        extra: {
          emails: emails.count,
          sms_message_ids: telephony_responses.map { |resp| resp.to_h[:message_id] },
        },
      )
    end
  end
end
