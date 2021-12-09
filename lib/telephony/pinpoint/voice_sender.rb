require 'time'

module Telephony
  module Pinpoint
    class VoiceSender
      # rubocop:disable Metrics/BlockLength
      def send(message:, to:, country_code:, otp: nil)
        return handle_config_failure if Telephony.config.pinpoint.voice_configs.empty?

        language_code, voice_id = language_code_and_voice_id

        last_error = nil
        Telephony.config.pinpoint.voice_configs.each do |voice_config|
          start = Time.zone.now
          client = build_client(voice_config)
          next if client.nil?
          response = client.send_voice_message(
            content: {
              ssml_message: {
                text: message,
                language_code: language_code,
                voice_id: voice_id,
              },
            },
            destination_phone_number: to,
            origination_phone_number: voice_config.longcode_pool.sample,
          )
          finish = Time.zone.now
          return Response.new(
            success: true,
            error: nil,
            extra: {
              message_id: response.message_id,
              duration_ms: Util.duration_ms(start: start, finish: finish),
            },
          )
        rescue Aws::PinpointSMSVoice::Errors::ServiceError,
               Seahorse::Client::NetworkingError => e
          finish = Time.zone.now
          last_error = handle_pinpoint_error(e)
          notify_pinpoint_failover(
            error: e,
            region: voice_config.region,
            extra: {
              message_id: response&.message_id,
              duration_ms: Util.duration_ms(start: start, finish: finish),
            },
          )
        end

        last_error || handle_config_failure
      end
      # rubocop:enable Metrics/BlockLength

      # @api private
      # @param [PinpointVoiceConfiguration] voice_config
      # @return [nil, Aws::PinpointSMSVoice::Client]
      def build_client(voice_config)
        credentials = AwsCredentialBuilder.new(voice_config).call
        return if credentials.nil?

        Aws::PinpointSMSVoice::Client.new(
          region: voice_config.region,
          retry_limit: 0,
          credentials: credentials,
        )
      end

      private

      def handle_pinpoint_error(err)
        request_id = if err.is_a?(Aws::PinpointSMSVoice::Errors::ServiceError)
                       err&.context&.metadata&.fetch(:request_id, nil)
                     end

        error_message = "#{err.class}: #{err.message}"
        error_class = if err.is_a? Aws::PinpointSMSVoice::Errors::LimitExceededException
                        Telephony::ThrottledError
                      else
                        Telephony::TelephonyError
                      end

        Response.new(
          success: false, error: error_class.new(error_message), extra: { request_id: request_id },
        )
      end

      def notify_pinpoint_failover(error:, region:, extra:)
        response = Response.new(
          success: false,
          error: error,
          extra: extra.merge(
            failover: true,
            region: region,
            channel: 'voice',
          ),
        )
        Telephony.config.logger.warn(response.to_h.to_json)
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

      def handle_config_failure
        response = Response.new(
          success: false,
          error: UnknownFailureError.new('Failed to load AWS config'),
          extra: {
            channel: 'sms',
          },
        )

        Telephony.config.logger.warn(response.to_h.to_json)

        response
      end
    end
  end
end
