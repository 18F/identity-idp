module IrsAttemptsApi
  class Tracker
    attr_reader :session_id

    def initialize(session_id:)
      @session_id = session_id
    end

    def track_event(event_type, metadata = {})
      return unless IdentityConfig.store.irs_attempt_api_enabled

      event = IrsAttemptsApi::Event.build(
        event_type: event_type,
        session_id: session_id,
        occurred_at: Time.zone.now,
        event_metadata: metadata,
      )
      redis_client.write_event(event)
    end

    private

    def redis_client
      @redis_client ||= IrsAttemptsApi::RedisClient.new
    end
  end
end
