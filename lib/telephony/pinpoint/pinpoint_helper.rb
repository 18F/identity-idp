module Telephony
  module Pinpoint
    module PinpointHelper
      def self.notify_pinpoint_failover(error:, region:, channel:, extra:)
        response = Response.new(
          success: false,
          error: error,
          extra: extra.merge(
            failover: true,
            region: region,
            channel: channel,
          ),
        )
        Telephony.config.logger.warn(response.to_h.to_json)
      end

      # @return [Response]
      def self.handle_config_failure(channel)
        response = Response.new(
          success: false,
          error: UnknownFailureError.new('Failed to load AWS config'),
          extra: {
            channel: channel,
          },
        )

        Telephony.config.logger.warn(response.to_h.to_json)

        response
      end
    end
  end
end
