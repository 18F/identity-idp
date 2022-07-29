module IrsAttemptsApi
  class Tracker
    attr_reader :session_id, :enabled_for_session, :request, :user, :sp

    def initialize(session_id:, request:, user:, sp:, enabled_for_session:)
      @session_id = session_id # IRS session ID
      @request = request
      @user = user
      @sp = sp
      @enabled_for_session = enabled_for_session
    end

    def track_event(event_type, metadata = {})
      return unless enabled?

      event_metadata = {
        user_agent: request&.headers['User-Agent'],
        unique_session_id: user&.unique_session_id,
        user_uuid: ServiceProviderIdentity.where(service_provider: sp.issuer, user_id: user.id).take&.uuid,
        user_ip_address: request&.remote_ip,
        irs_application_url: request&.headers['Referer'],
      }.merge(metadata)

      event = AttemptEvent.new(
        event_type: event_type,
        session_id: session_id,
        occurred_at: Time.zone.now,
        event_metadata: event_metadata,
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
