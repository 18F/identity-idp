module Telephony
  module Pinpoint
    module PinpointHelper
      def self.notify_pinpoint_failover(error:, region:, channel:, extra:)
        response = Response.new(
          success: false,
          error:,
          extra: extra.merge(
            failover: true,
            region:,
            channel:,
          ),
        )
        Telephony.log_warn(event: response.to_h)
      end

      # @return [Response]
      def self.handle_config_failure(channel)
        response = Response.new(
          success: false,
          error: UnknownFailureError.new('Failed to load AWS config'),
          extra: {
            channel:,
          },
        )

        Telephony.log_warn(event: response.to_h)

        response
      end
    end
  end
end
