module Telephony
  module Pinpoint
    class OptOutManager
      # @return [Response]
      def opt_in_phone_number(phone_number)
        if Telephony.config.pinpoint.sms_configs.empty?
          return PinpointHelper.handle_config_failure(:sns)
        end

        # binding.pry
        response = nil
        Telephony.config.pinpoint.sms_configs.each do |config|
          client = build_client(config)
          next if client.nil?

          opt_in_response = client.opt_in_phone_number(phone_number: phone_number)

          response = if opt_in_response.successful?
            check_response = client.check_if_phone_number_is_opted_out(phone_number: phone_number)

            Response.new(success: !check_response.is_opted_out, error: check_response.error)
          else
            Response.new(success: false, error: opt_in_response.error)
          end
        rescue Seahorse::Client::NetworkingError,
               Aws::SNS::Errors::InternalServerErrorException => error
          PinpointHelper.notify_pinpoint_failover(
            error: error,
            region: config.region,
            channel: :sns,
            extra: {},
          )
        end

        response || PinpointHelper.handle_config_failure(:sms)
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
