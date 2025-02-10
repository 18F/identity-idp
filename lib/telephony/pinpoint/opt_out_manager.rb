# frozen_string_literal: true

module Telephony
  module Pinpoint
    class OptOutManager
      # Tries to opt in across *all* regions because AWS keeps separate opt out lists
      # @return [Response]
      def opt_in_phone_number(phone_number)
        responses = Telephony.config.pinpoint.sms_configs.map do |config|
          client = build_client(config)
          next if client.nil?

          opt_in_response = client.opt_in_phone_number(phone_number: phone_number)

          Response.new(success: opt_in_response.successful?)
        rescue Aws::SNS::Errors::InvalidParameter
          # This is thrown when the number has been opted in too recently
          Response.new(success: false)
        rescue Seahorse::Client::NetworkingError,
               Aws::SNS::Errors::ServiceError => error
          PinpointHelper.notify_pinpoint_failover(
            error: error,
            region: config.region,
            channel: :notification_service,
            extra: {},
          )
          Response.new(success: false, error: error)
        end.compact

        return PinpointHelper.handle_config_failure(:notification_service) if responses.empty?

        # imitation of FormResponse#merge
        Response.new(
          success: responses.all?(&:success?),
          error: responses.map(&:error).compact.first,
          extra: responses.map(&:extra).reduce({}, :merge),
        )
      end

      # @return [Enumerator<String>]
      def opted_out_numbers
        Enumerator.new do |y|
          Telephony.config.pinpoint.sms_configs.each do |config|
            client = build_client(config)
            next if client.nil?

            client.list_phone_numbers_opted_out.each do |response|
              response.phone_numbers.each do |phone_number|
                y << phone_number
              end
            end
          end
        end
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
