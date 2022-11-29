module Telephony
  class OtpSender
    attr_reader :recipient_phone, :otp, :expiration, :channel, :domain, :country_code, :resend

    def initialize(to:, otp:, expiration:, channel:, domain:, country_code:, extra_metadata:)
      @recipient_phone = to
      @otp = otp
      @expiration = expiration
      @channel = channel.to_sym
      @domain = domain
      @country_code = country_code
      @resend = resend
    end

    def send_authentication_otp
      response = adapter.send(
        message: authentication_message,
        to: recipient_phone,
        otp: otp,
        country_code: country_code,
      )
      log_response(response, context: :authentication)
      response
    end

    def send_confirmation_otp
      response = adapter.send(
        message: confirmation_message,
        to: recipient_phone,
        otp: otp,
        country_code: country_code,
      )
      log_response(response, context: :confirmation)
      response
    end

    def authentication_message
      wrap_in_ssml_if_needed(
        I18n.t(
          "telephony.authentication_otp.#{channel}",
          app_name: APP_NAME,
          code: otp_transformed_for_channel,
          expiration: expiration,
          domain: domain,
        ),
      )
    end

    def confirmation_message
      wrap_in_ssml_if_needed(
        I18n.t(
          "telephony.confirmation_otp.#{channel}",
          app_name: APP_NAME,
          code: otp_transformed_for_channel,
          expiration: expiration,
          domain: domain,
        ),
      )
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

    def otp_transformed_for_channel
      return otp if channel != :voice

      otp.chars.join(" <break time='#{Telephony.config.voice_pause_time}' /> ")
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
