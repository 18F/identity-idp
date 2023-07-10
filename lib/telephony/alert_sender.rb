module Telephony
  class AlertSender < BasicSender
    SMS_MAX_LENGTH = 160

    def send_account_reset_notice(to:, country_code:)
      message = I18n.t('telephony.account_reset_notice', app_name: APP_NAME)
      response = adapter.send(message: message, to: to, country_code: country_code)
      log_response(response, context: __method__.to_s.gsub(/^send_/, ''))
      response
    end

    def send_account_reset_cancellation_notice(to:, country_code:)
      message = I18n.t('telephony.account_reset_cancellation_notice', app_name: APP_NAME)
      response = adapter.send(message: message, to: to, country_code: country_code)
      log_response(response, context: __method__.to_s.gsub(/^send_/, ''))
      response
    end

    def send_doc_auth_link(to:, link:, country_code:, sp_or_app_name:)
      message = I18n.t(
        'telephony.doc_auth_link',
        app_name: APP_NAME,
        sp_or_app_name: sp_or_app_name,
        link: link,
      )
      response = adapter.send(message: message, to: to, country_code: country_code)
      context = __method__.to_s.gsub(/^send_/, '')
      if link.length > SMS_MAX_LENGTH
        log_warning("link longer than #{SMS_MAX_LENGTH} characters", context: context)
      end
      log_response(response, context: context)
      response
    end

    def send_personal_key_regeneration_notice(to:, country_code:)
      message = I18n.t('telephony.personal_key_regeneration_notice', app_name: APP_NAME)
      response = adapter.send(message: message, to: to, country_code: country_code)
      log_response(response, context: __method__.to_s.gsub(/^send_/, ''))
      response
    end

    def send_personal_key_sign_in_notice(to:, country_code:)
      message = I18n.t('telephony.personal_key_sign_in_notice', app_name: APP_NAME)
      response = adapter.send(message: message, to: to, country_code: country_code)
      log_response(response, context: __method__.to_s.gsub(/^send_/, ''))
      response
    end
  end
end
