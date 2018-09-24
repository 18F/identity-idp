module TwilioErrors
  REST_ERRORS = {
    13_224 => I18n.t('errors.messages.invalid_voice_number'),
    21_211 => I18n.t('errors.messages.invalid_phone_number'),
    21_215 => I18n.t('errors.messages.invalid_calling_area'),
    21_614 => I18n.t('errors.messages.invalid_sms_number'),
    4_815_162_342 => I18n.t('errors.messages.twilio_timeout'),
  }.freeze

  VERIFY_ERRORS = {
    60_033 => I18n.t('errors.messages.invalid_phone_number'),
    # invalid country code
    60_078 => I18n.t('errors.messages.invalid_phone_number'),
    # cannot send sms to landline
    60_082 => I18n.t('errors.messages.invalid_sms_number'),
    # phone number not provisioned with any carrier
    60_083 => I18n.t('errors.messages.invalid_phone_number'),
    # Request timed out or connection failed
    4_815_162_342 => I18n.t('errors.messages.twilio_timeout'),
  }.freeze
end
