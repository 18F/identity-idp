module Features
  module LocalizationHelper
    def invalid_phone_message
      t('errors.messages.improbable_phone')
    end

    def unsupported_phone_message
      t('errors.messages.invalid_phone_number')
    end

    def unsupported_sms_message
      t('errors.messages.invalid_sms_number')
    end

    def failed_to_send_otp
      t('errors.messages.otp_failed')
    end

    def invalid_email_message
      t('valid_email.validations.email.invalid')
    end
  end
end
