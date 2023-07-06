module Telephony
  class NotificationSender
    attr_reader :notification_message, :recipient_phone, :expiration, :channel, :domain,
                :country_code, :extra_metadata

    def initialize(message:, to:, expiration:,
                   channel:, domain:, country_code:, extra_metadata:)
      @notification_message = message
      @recipient_phone = to
      @expiration = expiration
      @channel = channel.to_sym
      @domain = domain
      @country_code = country_code
      @extra_metadata = extra_metadata
    end

    def send_notification
      response = adapter.send(
        message: wrap_in_ssml_if_needed(notification_message),
        to: recipient_phone,
        otp: nil,
        country_code: country_code,
      )
      log_response(response, context: :authentication)
      response
    end

    private

    def adapter
      case [Telephony.config.adapter, channel.to_sym]
      when [:pinpoint, :sms]
        Pinpoint::SmsSender.new
      when [:pinpoint, :voice]
        Pinpoint::VoiceSender.new
      when [:test, :sms]
        Test::SmsSender.new
      when [:test, :voice]
        Test::VoiceSender.new
      else
        raise "Unknown telephony adapter #{Telephony.config.adapter} for channel #{channel.to_sym}"
      end
    end

    def log_response(response, context:)
      extra = extra_metadata.merge(
        {
          adapter: Telephony.config.adapter,
          channel: channel,
          context: context,
          country_code: country_code,
        },
      )
      output = response.to_h.merge(extra).to_json
      Telephony.config.logger.info(output)
    end

    def wrap_in_ssml_if_needed(message)
      return message if channel != :voice

      <<~XML.squish
        <speak>
          <prosody rate='#{Telephony.config.voice_rate}'>
            #{message}
          </prosody>
        </speak>
      XML
    end
  end
end
