module Features
  module LocalizationHelper
    def invalid_mobile_message
      t('errors.messages.improbable_phone')
    end

    def invalid_email_message
      t('valid_email.validations.email.invalid')
    end
  end
end
