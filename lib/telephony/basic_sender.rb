# frozen_string_literal: true

module Telephony
  class BasicSender
    def send_raw_message(to:, message:, country_code:)
      response = adapter.send(message: message, to: to, country_code: country_code)
      log_response(response, context: __method__.to_s.gsub(/^send_/, ''))
      response
    end

    alias send_notification send_raw_message

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
