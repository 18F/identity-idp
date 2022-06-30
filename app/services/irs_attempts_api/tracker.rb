module IrsAttemptsApi
  class Tracker
    attr_reader :session_id, :enabled_for_session

    def initialize(session_id:, enabled_for_session:)
      @session_id = session_id
      @enabled_for_session = enabled_for_session
    end

    def track_event(event_type, metadata = {})
      return unless enabled?

      event = AttemptEvent.new(
        event_type: event_type,
        session_id: session_id,
        occurred_at: Time.zone.now,
        event_metadata: metadata,
      )

      redis_client.write_event(jti: event.jti, jwe: event.to_jwe)
      event
    end

    include TrackerEvents

    private

    def enabled?
      IdentityConfig.store.irs_attempt_api_enabled && @enabled_for_session
    end

    def redis_client
      @redis_client ||= IrsAttemptsApi::RedisClient.new
    end
  end
end
