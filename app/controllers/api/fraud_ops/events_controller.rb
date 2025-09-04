# frozen_string_literal: true

module Api
  module FraudOps
    class EventsController < Attempts::EventsController
      private

      def redis_client
        @redis_client ||= FraudOpsTracker::RedisClient.new
      end

      def request_token
        @request_token ||= FraudOpsTracker::RequestTokenValidator.new(request.authorization)
      end

      # TODO: Define custom analytics event
      def track_failure
        analytics.attempts_api_poll_events_request(
          issuer: 'fraudops',
          requested_events_count: nil,
          requested_acknowledged_events_count: nil,
          returned_events_count: nil,
          acknowledged_events_count: nil,
          success: false,
        )
      end

      def event_limit
        IdentityConfig.store.fraud_ops_event_limit || 1000
      end
    end
  end
end
