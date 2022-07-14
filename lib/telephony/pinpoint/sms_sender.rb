require 'time'

module Telephony
  module Pinpoint
    class SmsSender
      ERROR_HASH = {
        'DUPLICATE' => DuplicateEndpointError,
        'OPT_OUT' => OptOutError,
        'PERMANENT_FAILURE' => PermanentFailureError,
        'TEMPORARY_FAILURE' => TemporaryFailureError,
        'THROTTLED' => ThrottledError,
        'TIMEOUT' => TimeoutError,
        'UNKNOWN_FAILURE' => UnknownFailureError,
      }.freeze

      # rubocop:disable Metrics/BlockLength
      # rubocop:disable Lint/UnusedMethodArgument
      # @return [Response]
      def send(message:, to:, country_code:, otp: nil)
        if Telephony.config.pinpoint.sms_configs.empty?
          return PinpointHelper.handle_config_failure(:sms)
        end

        response = nil
        Telephony.config.pinpoint.sms_configs.each do |sms_config|
          start = Time.zone.now
          client = build_client(sms_config)
          next if client.nil?
          pinpoint_response = client.send_messages(
            application_id: sms_config.application_id,
            message_request: {
              addresses: {
                to => {
                  channel_type: 'SMS',
                },
              },
              message_configuration: {
                sms_message: {
                  body: message,
                  message_type: 'TRANSACTIONAL',
                  origination_number: origination_number(country_code, sms_config),
                  sender_id: Telephony.config.country_sender_ids[country_code.to_s],
                },
              },
            },
          )
          finish = Time.zone.now
          response = build_response(pinpoint_response, start: start, finish: finish)
          if response.success? ||
             response.error.is_a?(OptOutError) ||
             response.error.is_a?(PermanentFailureError)
            return response
          end
          PinpointHelper.notify_pinpoint_failover(
            error: response.error,
            region: sms_config.region,
            channel: :sms,
            extra: response.extra,
          )
        rescue Aws::Pinpoint::Errors::ServiceError,
               Seahorse::Client::NetworkingError => e
          finish = Time.zone.now
          response = handle_pinpoint_error(e)
          PinpointHelper.notify_pinpoint_failover(
            error: e,
            region: sms_config.region,
            channel: :sms,
            extra: {
              duration_ms: Util.duration_ms(start: start, finish: finish),
            },
          )
        end
        response || PinpointHelper.handle_config_failure(:sms)
      end
      # rubocop:enable Lint/UnusedMethodArgument
      # rubocop:enable Metrics/BlockLength

      def phone_info(phone_number)
        if Telephony.config.pinpoint.sms_configs.empty?
          return PinpointHelper.handle_config_failure(:sms)
        end

        response = nil
        error = nil

        Telephony.config.pinpoint.sms_configs.each do |sms_config|
          error = nil
          client = build_client(sms_config)
          next if client.nil?
          response = client.phone_number_validate(
            number_validate_request: { phone_number: phone_number },
          )
          break if response
        rescue Seahorse::Client::NetworkingError,
               Aws::Pinpoint::Errors::InternalServerErrorException => error
          PinpointHelper.notify_pinpoint_failover(
            error: error,
            region: sms_config.region,
            channel: :sms,
            extra: {},
          )
        end

        type = case response&.number_validate_response&.phone_type
        when 'MOBILE'
          :mobile
        when 'LANDLINE'
          :landline
        when 'VOIP'
          :voip
        else
          :unknown
        end

        error ||= unknown_failure_error if !response

        PhoneNumberInfo.new(
          type: type,
          carrier: response&.number_validate_response&.carrier,
          error: error,
        )
      end

      # @api private
      # @param [PinpointSmsConfig] sms_config
      # @return [nil, Aws::Pinpoint::Client]
      def build_client(sms_config)
        credentials = AwsCredentialBuilder.new(sms_config).call
        return if credentials.nil?
        Aws::Pinpoint::Client.new(
          region: sms_config.region,
          retry_limit: 0,
          credentials: credentials,
        )
      end

      def origination_number(country_code, sms_config)
        if sms_config.country_code_longcode_pool&.dig(country_code).present?
          sms_config.country_code_longcode_pool[country_code].sample
        else
          sms_config.shortcode
        end
      end

      private

      def handle_pinpoint_error(err)
        error_message = "#{err.class}: #{err.message}"

        Response.new(
          success: false, error: Telephony::TelephonyError.new(error_message),
        )
      end

      def build_response(pinpoint_response, start:, finish:)
        message_response_result = pinpoint_response.message_response.result.values.first

        Response.new(
          success: success?(message_response_result),
          error: error(message_response_result),
          extra: {
            request_id: pinpoint_response.message_response.request_id,
            delivery_status: message_response_result.delivery_status,
            message_id: message_response_result.message_id,
            status_code: message_response_result.status_code,
            status_message: message_response_result.status_message.gsub(/\d/, 'x'),
            duration_ms: Util.duration_ms(start: start, finish: finish),
          },
        )
      end

      def success?(message_response_result)
        message_response_result.delivery_status == 'SUCCESSFUL'
      end

      def error(message_response_result)
        return nil if success?(message_response_result)

        status_code = message_response_result.status_code
        delivery_status = message_response_result.delivery_status
        exception_message = "Pinpoint Error: #{delivery_status} - #{status_code}"
        exception_class =
          if permanent_failure_opt_out?(message_response_result)
            OptOutError
          else
            ERROR_HASH[delivery_status] || TelephonyError
          end
        exception_class.new(exception_message)
      end

      # Sometimes AWS Pinpoint returns PERMANENT_FAILURE with an "opted out" message
      # instead of an OPT_OUT error
      # @param [Aws::Pinpoint::Types::MessageResult] message_response_result
      def permanent_failure_opt_out?(message_response_result)
        message_response_result.delivery_status == 'PERMANENT_FAILURE' &&
          message_response_result.status_message&.include?('opted out')
      end

      def unknown_failure_error
        UnknownFailureError.new('Failed to load AWS config')
      end
    end
  end
end
