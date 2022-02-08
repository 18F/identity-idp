module Telephony
  module Pinpoint
    class OptOutManager
      # @return [Response]
      def opt_in_phone_number(phone_number)
        Telephony.config.pinpoint.sms_configs.each do |config|
          client = build_client(config)
          next if client.nil?

          opt_in_response = client.opt_in_phone_number(phone_number: phone_number)

          return Response.new(success: opt_in_response.successful?)
        rescue Aws::SNS::Errors::InvalidParameter
          # This is thrown when the number has been opted in too recently
          return Response.new(success: false)
        rescue Seahorse::Client::NetworkingError,
               Aws::SNS::Errors::ServiceError => error
          PinpointHelper.notify_pinpoint_failover(
            error: error,
            region: config.region,
            channel: :notification_service,
            extra: {},
          )
        end

        PinpointHelper.handle_config_failure(:notification_service)
      end

      # @api private
      # @param [PinpointSmsConfig] config
      # @return [nil, Aws::SNS::Client]
      def build_client(config)
        credentials = AwsCredentialBuilder.new(config).call
        return if credentials.nil?
        Aws::SNS::Client.new(
          region: config.region,
          retry_limit: 0,
          credentials: credentials,
        )
      end
    end
  end
end
