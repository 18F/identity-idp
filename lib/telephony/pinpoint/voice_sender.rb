require 'time'

module Telephony
  module Pinpoint
    class VoiceSender
      # One connection pool per config (aka per-region)
      CLIENT_POOL = Hash.new do |h, voice_config|
        h[voice_config] = ConnectionPool.new(size: IdentityConfig.store.pinpoint_voice_pool_size) do
          credentials = AwsCredentialBuilder.new(voice_config).call

          Aws::PinpointSMSVoice::Client.new(
            region: voice_config.region,
            retry_limit: 0,
            credentials: credentials,
          )
        end
      end

      # rubocop:disable Lint/UnusedMethodArgument
      # rubocop:disable Metrics/BlockLength
      def send(message:, to:, country_code:, otp: nil)
        if Telephony.config.pinpoint.voice_configs.empty?
          return PinpointHelper.handle_config_failure(:voice)
        end

        language_code, voice_id = language_code_and_voice_id
        last_error = nil
        Telephony.config.pinpoint.voice_configs.each do |voice_config|
          start = Time.zone.now
          CLIENT_POOL[voice_config].with do |client|
            origination_phone_number = voice_config.longcode_pool.sample

            response = client.send_voice_message(
              content: {
                ssml_message: {
                  text: message,
                  language_code: language_code,
                  voice_id: voice_id,
                },
              },
              destination_phone_number: to,
              origination_phone_number: origination_phone_number,
            )
            finish = Time.zone.now
            return Response.new(
              success: true,
              error: nil,
              extra: {
                message_id: response.message_id,
                duration_ms: Util.duration_ms(start: start, finish: finish),
                origination_phone_number: origination_phone_number,
              },
            )
          rescue Aws::PinpointSMSVoice::Errors::ServiceError,
                 Seahorse::Client::NetworkingError => e
            finish = Time.zone.now
            last_error = handle_pinpoint_error(e)
            PinpointHelper.notify_pinpoint_failover(
              error: e,
              region: voice_config.region,
              channel: :voice,
              extra: {
                message_id: response&.message_id,
                duration_ms: Util.duration_ms(start: start, finish: finish),
              },
            )
          end
        end

        last_error || PinpointHelper.handle_config_failure(:voice)
      end
      # rubocop:enable Metrics/BlockLength
      # rubocop:enable Lint/UnusedMethodArgument

      private

      def handle_pinpoint_error(err)
        request_id = if err.is_a?(Aws::PinpointSMSVoice::Errors::ServiceError)
                       err&.context&.metadata&.fetch(:request_id, nil)
                     end

        error_message = "#{err.class}: #{err.message}"
        error_class = if err.is_a? Aws::PinpointSMSVoice::Errors::LimitExceededException
                        Telephony::ThrottledError
                      elsif err.is_a? Aws::PinpointSMSVoice::Errors::TooManyRequestsException
                        Telephony::DailyLimitReachedError
                      else
                        Telephony::TelephonyError
                      end

        Response.new(
          success: false, error: error_class.new(error_message), extra: { request_id: request_id },
        )
      end

      def language_code_and_voice_id
        case I18n.locale.to_sym
        when :en
          ['en-US', 'Joey']
        when :fr
          ['fr-FR', 'Mathieu']
        when :es
          ['es-US', 'Miguel']
        else
          ['en-US', 'Joey']
        end
      end
    end
  end
end
