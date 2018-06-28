module TwilioErrors
  REST_ERRORS = {
    13_224 => I18n.t('errors.messages.invalid_voice_number'),
    21_211 => I18n.t('errors.messages.invalid_phone_number'),
    21_215 => I18n.t('errors.messages.invalid_calling_area'),
    21_614 => I18n.t('errors.messages.invalid_sms_number'),
  }.freeze
end
