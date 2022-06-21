module Telephony
  class TelephonyError < StandardError
    def friendly_message
      I18n.t(friendly_error_message_key)
    end

    protected

    def friendly_error_message_key
      # i18n-tasks-use t('telephony.error.friendly_message.generic')
      'telephony.error.friendly_message.generic'
    end
  end

  class InvalidPhoneNumberError < TelephonyError
    def friendly_error_message_key
      # i18n-tasks-use t('telephony.error.friendly_message.invalid_phone_number')
      'telephony.error.friendly_message.invalid_phone_number'
    end
  end

  class InvalidCallingAreaError < TelephonyError
    def friendly_error_message_key
      # i18n-tasks-use t('telephony.error.friendly_message.invalid_calling_area')
      'telephony.error.friendly_message.invalid_calling_area'
    end
  end

  class VoiceUnsupportedError < TelephonyError
    def friendly_error_message_key
      # i18n-tasks-use t('telephony.error.friendly_message.voice_unsupported')
      'telephony.error.friendly_message.voice_unsupported'
    end
  end

  class SmsUnsupportedError < TelephonyError
    def friendly_error_message_key
      # i18n-tasks-use t('telephony.error.friendly_message.sms_unsupported')
      'telephony.error.friendly_message.sms_unsupported'
    end
  end

  class DuplicateEndpointError < TelephonyError
    def friendly_error_message_key
      # i18n-tasks-use t('telephony.error.friendly_message.duplicate_endpoint')
      'telephony.error.friendly_message.duplicate_endpoint'
    end
  end

  class OptOutError < TelephonyError
    def friendly_error_message_key
      # i18n-tasks-use t('telephony.error.friendly_message.opt_out')
      'telephony.error.friendly_message.opt_out'
    end
  end

  class PermanentFailureError < TelephonyError
    def friendly_error_message_key
      # i18n-tasks-use t('telephony.error.friendly_message.permanent_failure')
      'telephony.error.friendly_message.permanent_failure'
    end
  end

  class TemporaryFailureError < TelephonyError
    def friendly_error_message_key
      # i18n-tasks-use t('telephony.error.friendly_message.temporary_failure')
      'telephony.error.friendly_message.temporary_failure'
    end
  end

  class ThrottledError < TelephonyError
    def friendly_error_message_key
      # i18n-tasks-use t('telephony.error.friendly_message.throttled')
      'telephony.error.friendly_message.throttled'
    end
  end

  class DailyLimitReachedError < TelephonyError
    def friendly_error_message_key
      # i18n-tasks-use t('telephony.error.friendly_message.daily_voice_limit_reached')
      'telephony.error.friendly_message.daily_voice_limit_reached'
    end
  end

  class TimeoutError < TelephonyError
    def friendly_error_message_key
      # i18n-tasks-use t('telephony.error.friendly_message.timeout')
      'telephony.error.friendly_message.timeout'
    end
  end

  class UnknownFailureError < TelephonyError
    def friendly_error_message_key
      # i18n-tasks-use t('telephony.error.friendly_message.unknown_failure')
      'telephony.error.friendly_message.unknown_failure'
    end
  end
end
