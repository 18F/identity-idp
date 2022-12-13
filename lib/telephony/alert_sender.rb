module Telephony
  class AlertSender
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

    def send_doc_auth_link(to:, link:, country_code:, service_provider:)
      message = I18n.t(
        'telephony.doc_auth_link',
        app_name: APP_NAME,
        service_provider: service_provider,
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
      message = I18n.t('telephony.personal_key_sign_in_notice')
      response = adapter.send(message: message, to: to, country_code: country_code)
      log_response(response, context: __method__.to_s.gsub(/^send_/, ''))
      response
    end

    private

    def adapter
      case Telephony.config.adapter
      when :pinpoint
        Pinpoint::SmsSender.new
      when :test
        Test::SmsSender.new
      end
    end

    def log_response(response, context:)
      extra = {
        adapter: Telephony.config.adapter,
        channel: :sms,
        context: context,
      }
      output = response.to_h.merge(extra).to_json
      Telephony.config.logger.info(output)
    end

    def log_warning(alert, context:)
      Telephony.config.logger.warn(
        {
          alert: alert,
          adapter: Telephony.config.adapter,
          channel: :sms,
          context: context,
        }.to_json,
      )
    end
  end
end
